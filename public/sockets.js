var ws;
var camp = {};
var server = {};

var game = {
  messages: [],
  buildings: {
    storage: {
      wood: {baseCost: {wood: 100}, factor: 1.25, amount: 500},
      stone: {baseCost: {wood: 1000}, factor: 2, amount: 50}
    },
    production: {
      wood: {baseCost: {wood: 100}, factor: 2}
    }
  }
};

function connectSocket() {
  window.ws = new WebSocket('ws://' + window.location.host + window.location.pathname);

  window.ws.onopen = function() {
    console.log('websocket opened');
    setTimeout(function() {checkSocket();}, 2000);
  };
  window.ws.onclose = function() {
    console.log('websocket closed');
  };
  window.ws.onmessage = function(m) {
    showMsg(m.data);
  };
}

function checkSocket() {
  if (window.ws.readyState != window.ws.OPEN) {
    console.log('uh oh.');
    connectSocket();
  }

  setTimeout(function() {checkSocket();}, 2000);
}

function reconnectActions() {
  $('.steal').unbind();
  $('.donate').unbind();
  $('.build').unbind();

  $('.steal').click(function() { 
    type = $(this).data('type');
    
    steal = parseInt($('#stealAmount').val());
    if (isNaN(steal)) {
      steal = 100;
    }

    if (camp.resource[type] === undefined) {
      speace = 100
    } else {
      space = camp.resource[type].max - camp.resource[type].amount;
    }

    if (space < steal) {
      steal = space;
    }

    window.ws.send(JSON.stringify({
      action: "steal",
      amount: steal,
      type:   type
    }));
    return false;
  });

  $('.donate').click(function() { 
    window.ws.send(JSON.stringify({
      action: "donate",
      type:   $(this).data('type'),
      amount: camp.resource[$(this).data('type')].amount
    }));
    amount: camp.resource[$(this).data('type')].amount = 0;
    redrawCamp();
  });

  $('.build').click(function() {
    // No need to notify the server just yet...
    type = $(this).data('type');
    building = game.buildings.storage[type];
    
    if (camp.buildings[type] === undefined) {
      camp.buildings[type] = 0;
    }
    owned = camp.buildings[type];

    cost = building.baseCost;

    canBuild = true;
    // First pass - check we can afford it...
    for (var key in cost) {
      resCost = cost[key] * Math.pow(building.factor, owned);
      console.log("Action will cost " + resCost + " " + key + ". (Have " + camp.resource[key].amount + ")");
      if (camp.resource[key].amount < resCost) {
        canBuild = false;
      }
    }

    // Second pass - do it!
    if (canBuild) {
      for (var key in cost) {
        resCost = cost[key] * Math.pow(building.factor, owned);
        camp.resource[key].amount -= parseInt(resCost);
      }
      camp.resource[type].max += building.amount;
      camp.buildings[type] += 1;
    }
  });
}

function setupCamp() {
  camp["resource"] = {};
  camp["resource"]["wood"] = {max: 500, amount: 0, shown: false};
  camp["buildings"] = {};

  server["resource"] = {};
}


function showMsg(m) {
  j = JSON.parse(m);
  switch(j.message) {
    case "update":
      updateServer(j);
      break;
    case "award":
      updateLocal(j);
      break;
    case "chat":
      addChat(j);
      break;
    default:
      console.log("Can't process " + j.message + " type...");
  }
}

function addChat(j) {
  text = "<p>" + j.who + ": " + j.msg + "</p>";
  game.messages.unshift(text);
  game.messages = game.messages.slice(0,9);
  
  content = game.messages.slice(0, 9); 
 
  $('#msgs').html(content);
}

function updateServer(j) {
  users = j.users;
  $('#userCount').html(users);

  for (var key in j.resource) {
    max = j.resource[key].max;
    amount = j.resource[key].amount;
    server["resource"][key] = {name: key, max: parseInt(max), amount: parseInt(amount)};
  } 

  redrawCamp();
}

function updateLocal(j) {
  if (camp.resource[j.type] === undefined) {
    camp.resource[j.type] = {max: 100, amount: 0, shown: false};
  }
  camp.resource[j.type].shown = true;
  camp.resource[j.type].amount += parseInt(j.amount);
  if (camp.resource[j.type].amount > camp.resource[j.type].max) {
    camp.resource[j.type].amount = camp.resource[j.type].max;
  }

  redrawCamp();
}

function redrawCamp() {
  for (var key in server["resource"]) {
    r = server["resource"][key]
    // Unlike camp, if we know about it, show it.
    if ($('#'+key+"ServerContainer").length == 0) {
      html =  '<div id="'+key+'ServerContainer">';
      html += '  <div class="progress" style="width:70%; float:left;">';
      html += '    <div id="'+key+'ServerBar" class="progress-bar progress-bar-danger" role="progressbar" aria-valuenow="0" aria-valuemin="0" aria-valuemax="100" style="width: 0%;">';
      html += '      <div>'+key+'</div>';
      html += '    </div>';
      html += '  </div>';
      html += '  <p><span id="'+key+'ServerText"></span>';
      html += '  <button id="'+key+'Steal" class="steal" data-type="'+key+'">Steal</button>';
      html += '  </p>';
      html += '  <div style="clear: both;"></div>';
      html += '</div>';

      $('#server').append(html);
    }

    current = r.amount;
    total = r.max;

    $('#'+key+"ServerBar").attr('aria-valuenow', current);
    $('#'+key+"ServerBar").attr('aria-valuemax', total);
      
    $('#'+key+"ServerBar").css('width', (current * 100/total)+'%');
    $('#'+key+"ServerText").html(current + " / " + total);
  }


  for (var key in camp["resource"]) {
    r = camp["resource"][key]
    if (r.shown) {

      if ($('#'+key+"Container").length == 0) {
        html =  '<div id="'+key+'Container">';
        html += '  <div class="progress" style="width:70%; float:left;">';
        html += '    <div id="'+key+'LocalBar" class="progress-bar progress-bar-success" role="progressbar" aria-valuenow="0" aria-valuemin="0" aria-valuemax="100" style="width: 0%;">';
        html += '    <div>'+key+'</div>';
        html += '    </div>';
        html += '  </div>';
        html += '  <p><span id="'+key+'LabelText"></span>';
        html += '    <button id="'+key+'Donate" class="donate" data-type="'+key+'" >Donate</button>';
        if (game.buildings.storage[key] != undefined) {
          html += '    <button id="'+key+'Build" class="build" data-type="'+key+'" >Build</button>';
        }
        html += '  </p>';
        html += '  <div style="clear: both;"></div>';
        html += '</div>';

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

  reconnectActions();
}

