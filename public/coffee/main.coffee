ModPrezi = {}
class ModPrezi.Prezi
  constructor: (obj) ->
    {@title, @url, @thumbnail} = obj
    @id = obj.prezi_id
    @description = obj.info

  reduceDescriptionLength: =>
    limit = @description.split(" ")[0..9].join(" ").length
    temp_p = @description.substring(0, limit) + "...";


class ModPrezi.PreziRes
  constructor: (res) ->
    {@has_items, @message, @quantity, @page, @has_next, @objects} = res
    @prezi_origin_url = res.prezi_url

  @fromJson: (json) ->
    res = JSON.parse(json)
    prezis = []
    for obj in res.objects
      prezis.push new ModPrezi.Prezi(obj)
    res.objects = prezis
    new ModPrezi.PreziRes(res);

class ModPrezi.Backend
  constructor: (@app, @gui, @params = {}) ->

  fetchPrezis: (call_prezi_url, params = null) =>
    fetch_url = call_prezi_url
    enable_more_button = false
    if params? and @params != params
      enable_more_button = true
      @params = params
      fetch_url = call_prezi_url+ "?search_title="+params["title"]+"&page_number="+params["page_number"];
      if params["page_number"] == 1
        @gui.cleanFeedContainer(true)

    @gui.startLoading()
    request = $.ajax(
      url: fetch_url
      type: 'GET'
      contentType: 'apllication/json'
    )
    .then (response) =>
      @gui.stopLoading(enable_more_button)
      ModPrezi.PreziRes.fromJson(response)

class ModPrezi.Gui
  constructor: (@app, search_field_dom, @search_trigger, @more_trigger, prezis_feed_container) ->
    @feed_container = prezis_feed_container
    @cleanFeed = true
    @page_number = 1
    @prezi_pair_count = 0

    $(search_field_dom).focus()
    $(search_field_dom).on 'keyup', (e) =>
      elem = $(search_field_dom)
      e.preventDefault()
      if e.keyCode == 13
        @page_number = 1
        this.searchTrigger $(search_field_dom).val()

    $(@search_trigger).on 'click', (e) =>
      e.preventDefault()
      @page_number = 1
      this.searchTrigger $(search_field_dom).val()

    $(@more_trigger).on 'click', (e) =>
      e.preventDefault()
      @page_number += 1
      $(@more_trigger).parent().hide()
      this.searchTrigger $(search_field_dom).val()

  searchTrigger: (search_value) =>
    @app.search(search_value, @page_number)

  cleanFeedContainer: (cleanFeed) =>
    @cleanFeed = cleanFeed

  preziRow: (prezi) =>
    $("<article class='col-xs-12 col-sm-6' data-oid='#{prezi.id}'>
        <div class='thumbnail'>
          <a href='#' id='prezi_item_thumbnail_link'>
            <img class='img-rounded' src='#{prezi.thumbnail}' alt='#{prezi.title}'/>
          </a>
          <div class='caption text-center'>
            <h3>#{prezi.title}</h3>
            <p id='prezi_item_description'>#{prezi.description}</p>
            <p class='row'>
              <button id='open_prezi_interaction' class='btn btn-primary btn-lg col-xs-4 col-xs-offset-1'>Preview</button>
              <button id='embed_prezi_interaction' class='btn btn-success btn-lg col-xs-4 col-xs-offset-2'>Embed</button>
            </p>
          </div>
        </div>
       </article>")

  addClearFix: =>
    $("<article class='clearfix visible-xs-block visible-sm-block'></article>")

  addPrezi: (prezi) =>
    @prezi_pair_count++
    if @prezi_pair_count == 3
      @prezi_pair_count = 0
      @addClearFix().appendTo(@feed_container)
      false
    else
      preziNode = @preziRow(prezi).appendTo(@feed_container)
      # @reduceDescriptionLength(preziNode, prezi)
      @bindRedirectFunction(preziNode, prezi.id)
      @bindEmbedFunction(preziNode, prezi.id)
      false

  reduceDescriptionLength: (preziNode, prezi) =>
    preziNode.find('#prezi_item_description').text(prezi.reduceDescriptionLength())

  bindRedirectFunction: (preziNode, prezi_id) =>
    preziNode.find('#prezi_item_thumbnail_link, #open_prezi_interaction').on 'click', (e) =>
      e.preventDefault()
      @app.redirect_to(prezi_id)

  bindEmbedFunction: (preziNode, prezi_id) =>
    preziNode.find("#embed_prezi_interaction").on 'click', (e) =>
      e.preventDefault()
      @app.embed(prezi_id)

  circleBall: =>
    $("<li>
        <div class='circle'></div>
        <div class='ball'></div>
      </li>")

  startLoading: =>
    loading_row = $("<div class='row' id='loading_row'>
                  <div class='loader_container col-xs-8 col-xs-offset-3 col-sm-4 col-sm-offset-5'>
                    <ul class='loader'>
                    </ul>
                  </div>
                 </div>")
    loader = loading_row.find('.loader')
    for num in [1..4]
      @circleBall().appendTo(loader)
    if(@cleanFeed)
      $(@feed_container).empty()
      @cleanFeed = false
    $(@feed_container).after(loading_row)

  stopLoading: (enable_more_button) =>
    $(@more_trigger).parent().toggle(enable_more_button)

    loading_row = $('#loading_row')
    if (loading_row)
      loading_row.remove();

class ModPrezi.App
  constructor: (search_field_dom, search_trigger, more_trigger, prezis_feed_container) ->
    @gui = new ModPrezi.Gui(this, search_field_dom, search_trigger, more_trigger, prezis_feed_container)
    @backend = new ModPrezi.Backend(this, @gui)

  renderResult: (prezisRes) ->
    for prezi in prezisRes.objects
      @gui.addPrezi(prezi)


  start: =>
    @backend.fetchPrezis("/call_prezi")
      .done( (prezisRes) =>
        this.renderResult(prezisRes)
      )
      .fail(@gui.fetchPrezisFailed)

  search: (field_value, page_number) =>
    @backend.fetchPrezis("/call_prezi", params={'title':field_value, 'page_number':page_number})
      .done( (prezisRes) =>
          this.renderResult(prezisRes)
      )
      .fail(@gui.fetchPrezisFailed)

  redirect_to: (prezi_id) =>
    location.href = "call_prezi?prezi_id="+prezi_id+"&launch_presentation_return_url="+url_to_embed+"&lti_type="+lti_type;

  embed: (prezi_id) =>
    url = ""
    if lti_type == "editor_button"
      url = url_to_embed+"?return_type=iframe&url=" + "https%3A%2F%2Fprezi.com%2Fembed%2F" + prezi_id + "%2F&width=400&height=350"
    else if lti_type == "resource_selection"
      host = location.protocol + "%2F%2F" + location.hostname
      if (location.port)
        host = host + ":" + location.port
      url = url_to_embed+"?return_type=lti_launch_url&url=" + (host + "%2Flti_tool?" + "prezi_id=" + prezi_id)
      url += "%26resource_selected=1"

    if(url.length != 0)
      location.href = url
    else
      alert("Nowhere to embed")

$(document).ready =>
  app = new ModPrezi.App("#search_prezi", "#search_prezi_trigger", "#bt_call_for_more", ".search-feed")
  app.start()
