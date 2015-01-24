var ws;
var camp = {};

function setupLocalCamp() {

  camp["resource"] = {};
  camp["resource"]["stone"] = {max: 0, amount: 0, shown: false};
  camp["resource"]["wood"] = {max: 500, amount: 0, shown: false};
}


function showMsg(m) {
  j = JSON.parse(m);
  switch(j.message) {
    case "update":
    case "setup":
      updateServer(j);
      break;
    case "award":
      updateLocal(j);
      break;
    default:
      console.log("Can't process " + j.message + " type...");
  }
}

function updateServer(j) {
  users = j.users;
  total = j.barCap;
  current = parseInt(j.barState);

  $('#serverBar').attr('aria-valuemax', total);
  $('#serverBar').attr('aria-valuenow', current);

  $('#serverBar').css('width', (current * 100/total)+'%');

  $('#userCount').html(users);

  $('#serverText').html(current + " / " + total);
}

function updateLocal(j) {
  camp["resource"]["wood"].shown = true;
  camp["resource"]["wood"].amount += parseInt(j.amount);
  if (camp["resource"]["wood"].amount > camp["resource"]["wood"].max) {
    camp["resource"]["wood"].amount = camp["resource"]["wood"].max;
  }

  redrawCamp();
}

function redrawCamp() {
  for (var key in camp["resource"]) {
    r = camp["resource"][key]
    if (r.shown) {

      if ($('#'+key+"Container").length == 0) {
        html = '<div id="'+key+'Container"><div class="progress" style="width:80%; float:left;"><div id="'+key+'LocalBar" class="progress-bar progress-bar-success" role="progressbar" aria-valuenow="0" aria-valuemin="0" aria-valuemax="100" style="width: 0%;"></div></div><p><span id="'+key+'LabelText"></span></p><div style="clear: both;"></div></div>'

        $('#resources').append(html);
      }

      current = r.amount;
      total = r.max;

      $('#'+key+"LocalBar").attr('aria-valuenow', current);
      $('#'+key+"LocalBar").attr('aria-valuemax', total);
      
      $('#'+key+"LocalBar").css('width', (current * 100/total)+'%');
      $('#'+key+"LabelText").html(current + " / " + total);
    }
  } 

  if ($('#resources').children().length > 0) {
    $('#resources').show();
  }
}

function stealServer() {
  window.ws.send(JSON.stringify({action: "steal"}));
}


