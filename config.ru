require 'rubygems'
require 'bundler'
require 'rack/coffee'
# bundler.require(:default)
# require 'sass/plugin/rack'
require './tool_provider'

# # use scss for stylesheets
# Sass::Plugin.options[:style] = :compressed
# use Sass::Plugin::Rack

# use coffeescript for javascript
use Rack::Coffee, root: 'public', urls: '/coffee'

run Sinatra::Application
