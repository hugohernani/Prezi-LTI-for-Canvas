ModPrezi = {}
class ModPrezi.PreziOptions
  constructor: (@options) ->

  getOptions: =>
    @options

class ModPrezi.Gui
  constructor: (@app, elem_dom) ->
    @prezi_elem = $("#"+elem_dom)

  renderButtons: (buttons_can_be_available) =>
    if buttons_can_be_available
      interaction_area = $("<div id='interaction'>
                              <button id='bt_embed' class='embed' type='button'>Embed</button>
                              <button id='bt_back' class='back' type='button'>Back</button>
                            </div>")

      @prezi_elem.after(interaction_area)


      interaction_area.find('#bt_embed').on 'click', (e) =>
        e.preventDefault()
        @app.embed()
      interaction_area.find('#bt_back').on 'click', (e) =>
        e.preventDefault()
        @app.goBack()


class ModPrezi.App
  constructor: (options) ->
    @preziFeatures = new ModPrezi.PreziOptions(options)

  start: (elem_dom) =>
    @player = new PreziPlayer elem_dom, @preziFeatures.getOptions()

    @gui = new ModPrezi.Gui(this, elem_dom)
    @gui.renderButtons(show_buttons)

  embed: =>
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

  goBack: =>
    history.go -1


$(document).ready =>
  app = new ModPrezi.App({preziId: prezi_id, width: "90%", height: 450, controls:true})
  app.start("prezi-player")
