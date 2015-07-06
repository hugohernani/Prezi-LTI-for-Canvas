var current_page = 1;
var current_url = "";

function set_navigation_status(has_next){
    has_next = has_next || false;

    if (has_next) {
        $("#more_items").show();
    } else{
        $("#more_items").hide();
    }
}

function render_loader(target_selector){
    target_selector = target_selector || ".search-feed"
    source = $("#loader-template").html();
    template = Handlebars.compile(source);
    target = $(target_selector);
    target.append(template({}));
}

function render_prezis(prezis, calling_more){
    source   = $("#search-feed-template").html();
    template = Handlebars.compile(source);
    context = JSON.parse(prezis);

    target = $(".search-feed");
    if(calling_more) target.append(template(context))
    else target.html(template(context));
    if(context.has_items && !calling_more) target.prepend("<h2>"+context.message+"</h2>");

    set_navigation_status(context.has_next);
}

function callOnPrezi(calling_more){
    calling_more = calling_more || false;

    search_prezi_field = $("#search_prezi");

    if ((search_prezi_field.data('oldVal') != search_prezi_field.val() && search_prezi_field.val().length != 0) || calling_more) {
        search_prezi_field.data('oldVal', search_prezi_field.val());
        current_url = "call_prezi?search_title="+search_prezi_field.val()+"&page_number="+current_page;
    }else{
        current_url = "call_prezi";
    }

    if(calling_more) {
        current_page+=1;
        render_loader();
        current_url = "call_prezi?search_title="+search_prezi_field.val()+"&page_number="+current_page;
    }
    else render_loader(".search-bar");
    $.ajax({
        url: current_url
    }).done(function(prezis) {
        render_prezis(prezis, calling_more);
    });
}

function embed(prezi_id){
    location.href = url_to_embed+"?return_type=iframe&url=" + "https%3A%2F%2Fprezi.com%2Fembed%2F" + prezi_id + "%2F&width=400&height=350";
}

function redirect_to(prezi_id){
    location.href = "call_prezi?prezi_id="+prezi_id+"&launch_presentation_return_url="+url_to_embed;
}

$(document).ajaxStop(function() {
    $(".loader_container").remove();
    ps_info = $(".prezi-item-info p")
    for(var i = 0; i < ps_info.size(); i++){
        temp_p = ps_info[i].textContent;
        limit = temp_p.split(" ").slice(0, 10).join(" ").length
        temp_p = temp_p.substring(0, limit) + "...";
        ps_info[i].textContent = temp_p
    }
});

$(document).ready(function() {
    callOnPrezi(false);

    // some triggers
    $("#search_prezi_trigger").click(function(){
        $(".search-feed").empty();
        callOnPrezi(calling_more=false);
    });
    $("#bt_call_for_more").click(function(){
        callOnPrezi(calling_more=true);
    });
});
