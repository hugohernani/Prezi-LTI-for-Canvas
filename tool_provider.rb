require 'sinatra'
require 'ims/lti'
# must include the oauth proxy object
require 'oauth/request_proxy/rack_request'
require 'nokogiri'
require 'json'
require 'open-uri'
require 'capybara'
require 'capybara/dsl'
require 'capybara/poltergeist'

Capybara.default_driver = :poltergeist
Capybara.run_server = false

enable :sessions
set :protection, :except => :frame_options

get '/' do
  erb :index
end

# the consumer keys/secrets. Consumer key: consumer_key; secret key: secrey_key
$oauth_creds = {"consumer_key" => "secret_key", "testing" => "supersecret"}

def show_error(message)
  @message = message
end

def authorize!
  if key = params['oauth_consumer_key']
    if secret = $oauth_creds[key]
      @tp = IMS::LTI::ToolProvider.new(key, secret, params)
    else
      @tp = IMS::LTI::ToolProvider.new(nil, nil, params)
      @tp.lti_msg = "Your consumer didn't use a recognized key."
      @tp.lti_errorlog = "You did it wrong!"
      show_error "Consumer key wasn't recognized"
      return false
    end
  else
    show_error "No consumer key"
    return false
  end

  if !@tp.valid_request?(request)
    show_error "The OAuth signature was invalid"
    return false
  end

  if Time.now.utc.to_i - @tp.request_oauth_timestamp.to_i > 60*60
    show_error "Your request is too old."
    return false
  end

  # this isn't actually checking anything like it should, just want people
  # implementing real tools to be aware they need to check the nonce
  if was_nonce_used_in_last_x_minutes?(@tp.request_oauth_nonce, 60)
    show_error "Why are you reusing the nonce?"
    return false
  end

  @username = @tp.username("Dude")

  true
end

module GetWebPage
  class WebScraper
    include Capybara::DSL

    def initialize(filter_phrase = nil)
      @list_of_placement = {}
      @filter_phrase = filter_phrase
    end

    def extract_content_into_json(page)
      puts "Lets extract..."
      prezis = Array.new
      divs = page.css("div[class='prezi-list-item thumbnail']")
      # divs_other = page.css("div")
      # puts "Divs other: " + divs_other.to_s

      # puts "Divs: " + divs.to_s
      divs.each{ |div|
        prezi_obj = {
            :title => div.css("div[class=caption] div[class='caption-inner'] h3 a")[0].text,
            :url => "/"+div["data-oid"]+"/",
            :prezi_id => div["data-oid"]
        }
        prezi_obj["info"] = @filter_phrase.nil? ? div.css("div[class=thumbnail-info] a").text : ""
        prezi_obj["thumbnail"] = @filter_phrase.nil? ? div.css("a[class=landing-link] img")[0]["src"] : div.css("a[class=landing_link]")[0]["style"].split(" ")[1].split("(")[1][0...-1]

        prezis.push prezi_obj
      }

      message = @filter_phrase.nil? ? "The #{divs.length} most popular presentations on Prezi.com" : "Search: " + @filter_phrase
      has_items = prezis.length > 0 ? true : false
      message = "No more results. Sorry. :/" unless has_items
      res = {
          :has_items => has_items,
          :message => message,
          :objects => prezis
      }
      res.to_json
    end


    def get_page_data(url, placement_id)
      return @list_of_placement[placement_id] if @list_of_placement.has_key?(placement_id)
        response = nil
        if @filter_phrase.nil?
            uri = URI.parse(URI.encode(url))
            http = Net::HTTP.new(uri.host, uri.port)
            http.use_ssl = true
            request = Net::HTTP::Get.new(uri.request_uri)
            response = http.request(request)
        else
            visit(URI.encode(url))
        end

        doc = @filter_phrase.nil? ? Nokogiri::HTML(response.body) : Nokogiri::HTML(page.html)
        json_response = extract_content_into_json(doc)
        @list_of_placement[placement_id] = json_response
        json_response
    end
  end
end

def parse_html_to_json(body, filter_phrase = nil)
  puts "Lets parse..."
  prezis = Array.new
  page = Nokogiri::HTML(body)
  divs = page.css("div[class='prezi-list-item thumbnail']")
  # divs_other = page.css("div")
  # puts "Divs other: " + divs_other.to_s

  # puts "Divs: " + divs.to_s
  divs.each{ |div|
    link = div.css("div[class=thumbnail-info] a")
    prezi_obj = {
        :title => div.css("div[class=caption] div[class=caption-inner] h3")[0]["data-shorttext"],
        :thumbnail => div.css("a[class=landing-link] img")[0]["src"],
        :url => "/"+div["data-oid"]+"/",
        :prezi_id => div["data-oid"]
    }
    prezi_obj["info"] = link[0].text unless link.nil?
    prezis.push prezi_obj
  }

  message = filter_phrase.nil? ? "The #{divs.length} most popular presentations on Prezi.com" : "Search: " + filter_phrase
  has_items = prezis.length > 0 ? true : false
  message = "No more results. Sorry. :/" unless has_items
  res = {
      :has_items => has_items,
      :message => message,
      :objects => prezis
  }
  res.to_json
end

get '/call_prezi' do

    if prezi_id = params["prezi_id"]
        erb :show_presentation, :locals => {:prezi_id => prezi_id, :return_embed_url => params["launch_presentation_return_url"]}
    else
        search_url = "https://prezi.com/explore/search/?search=SEARCH_TITLE#search=SEARCH_TITLE&reusable=false&page=PAGE_NUMBER&users=less"
        url = !params["search_title"].nil? ?
            search_url.gsub!("SEARCH_TITLE", params["search_title"]).gsub!("PAGE_NUMBER", params["page_number"]) :
            "https://prezi.com/explore/popular/"

        placement_id = params['resource_link_id']
        placement_id = placement_id +             params['tool_consumer_instance_guid'] unless            params['tool_consumer_instance_guid'].nil?
        scrapper = GetWebPage::WebScraper.new(params["search_title"])
        scrapper.get_page_data(url, placement_id)
    end
end

# The url for launching the tool
# It will verify the OAuth signature
post '/lti_tool' do
  return erb :error unless authorize!

  if @tp.outcome_service?
    # It's a launch for grading
    erb :assessment
  else
    # normal tool launch without grade write-back
    signature = OAuth::Signature.build(request, :consumer_secret => @tp.consumer_secret)

    @signature_base_string = signature.signature_base_string
    @secret = signature.send(:secret)

    if editor_button = params['editor_button']
        erb :list_presentations, :locals => {:return_embed_url => params["launch_presentation_return_url"]};
    elsif resource_selection = params['resource_selection']
        erb :list_presentations, :locals => {:return_embed_url => params["launch_presentation_return_url"]};
    else
        erb :boring_tool
    end
#        @tp.lti_msg = "Sorry that tool was so boring"
#        erb :boring_tool
  end
end

post '/signature_test' do
  erb :proxy_setup
end

post '/proxy_launch' do
  uri = URI.parse(params['launch_url'])

  if uri.port == uri.default_port
    host = uri.host
  else
    host = "#{uri.host}:#{uri.port}"
  end

  consumer = OAuth::Consumer.new(params['lti']['oauth_consumer_key'], params['oauth_consumer_secret'], {
      :site => "#{uri.scheme}://#{host}",
      :signature_method => "HMAC-SHA1"
  })

  path = uri.path
  path = '/' if path.empty?

  @lti_params = params['lti'].clone
  if uri.query != nil
    CGI.parse(uri.query).each do |query_key, query_values|
      unless @lti_params[query_key]
        @lti_params[query_key] = query_values.first
      end
    end
  end

  path = uri.path
  path = '/' if path.empty?

  proxied_request = consumer.send(:create_http_request, :post, path, @lti_params)
  signature = OAuth::Signature.build(proxied_request, :uri => params['launch_url'], :consumer_secret => params['oauth_consumer_secret'])

  @signature_base_string = signature.signature_base_string
  @secret = signature.send(:secret)
  @oauth_signature = signature.signature

  erb :proxy_launch
end

# post the assessment results
post '/assessment' do
  launch_params = request['launch_params']
  if launch_params
    key = launch_params['oauth_consumer_key']
  else
    show_error "The tool never launched"
    return erb :error
  end

  @tp = IMS::LTI::ToolProvider.new(key, $oauth_creds[key], launch_params)

  if !@tp.outcome_service?
    show_error "This tool wasn't lunched as an outcome service"
    return erb :error
  end

  # post the given score to the TC
  score = (params['score'] != '' ? params['score'] : nil)
  res = @tp.post_replace_result!(params['score'])

  if res.success?
    @score = params['score']
    @tp.lti_msg = "Message shown when arriving back at Tool Consumer."
    erb :assessment_finished
  else
    @tp.lti_errormsg = "The Tool Consumer failed to add the score."
    show_error "Your score was not recorded: #{res.description}"
    return erb :error
  end
end

get '/tool_config.xml' do
    host = request.scheme + "://" + request.host_with_port
    url = (params['signature_proxy_test'] ? host + "/signature_test" : host + "/lti_tool")
    tc = IMS::LTI::ToolConfig.new(:title => "Prezi tool for embed a presentation", :launch_url => url)
    tc.description = "That is a LTI tool for embedding prezi resource."

    tc.extend IMS::LTI::Extensions::Canvas::ToolConfig

    params_editor_button = {url:(host+"/lti_tool?editor_button=true"), icon_url:"https://prezi-a.akamaihd.net/dynapps-versioned/249-63d7e735841c3aaea538fda09bc6dcc25ba58bb4/common/img/favicon.ico", text:"Prezi", selection_width:800, selection_height:600, enabled:true};

    params_resource_selection = {url:(host+"/lti_tool?resource_selection=true"), text: "Select a presentation", selection_width:500, selection_height:600};

    tc.canvas_editor_button! params_editor_button
    tc.canvas_resource_selection! params_resource_selection

    headers 'Content-Type' => 'text/xml'
    tc.to_xml(:indent => 2)
end

def was_nonce_used_in_last_x_minutes?(nonce, minutes=60)
  # some kind of caching solution or something to keep a short-term memory of used nonces
  false
end
