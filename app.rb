require 'sinatra'
require 'sinatra-websocket'
require 'json'
require './models/resource'
require './models/users'

set :server, 'thin'
set :bind, '0.0.0.0'
$to_close = []

$resource = {}
tick = Proc.new { |cur, max, incr| cur + incr + (incr * 5 * (cur * 1.0 / (max * 0.8))) }
$resource["wood"]  = Resource.new("wood",  200, 3, 100, tick)
$resource["stone"] = Resource.new("stone", 0,   1, 0,   tick)
$resource["iron"]  = Resource.new("iron",  0,   0, 0,   tick)
$resource["oil"]   = Resource.new("oil",   0,   0, 0,   Proc.new { |c, m, i| c } )

wc = Building.new("Woodcutter",  [{'name' => "wood", 'amount' => 50}],                                       1.15, [{'type' => "wood", 'incr' => 3}])
sh = Building.new("Storage Hut", [{'name' => "wood", 'amount' => 100}],                                      1.2,  [{'type' => "wood", 'max' => 500}, {'type' => "stone", 'max' => 500}, {'type' => 'iron', "max" => 20}])
qy = Building.new("Quarry",      [{'name' => "wood", 'amount' => 50}, {'name' => "stone", 'amount' => 50}],  1.2,  [{'type' => "stone", 'incr' => 5}])
im = Building.new("Iron Mine",   [{"name" => "wood", "amount" => 100}, {"name" => "stone", "amount" => 50}], 1.3,  [{'type' => "iron", "incr" => 1}])
od = Building.new("Oil Drum",    [{"name" => "iron", "amount" => 10}],                                       1,    [{'type' => "oil", "max" => 5}])
dl = Building.new("Oil Drill",   [{"name" => "iron", "amount" => 100}, {"name" => "wood", "amount" => 150}], 1.2,  [{'type' => "oil", "incr" => 0.5}])

$buildings = {}
$buildings["Storage Hut"] = {'obj' => sh, 'num' => 0}
$buildings["Woodcutter"]  = {'obj' => wc, 'num' => 0}
$buildings["Quarry"]      = {'obj' => qy, 'num' => 0}
$buildings["Iron Mine"]   = {'obj' => im, 'num' => 0}
$buildings["Oil Drum"]    = {'obj' => od, 'num' => 0}
$buildings["Oil Drill"]   = {'obj' => dl, 'num' => 0}

$users    = []

# Keep this here for reasons...
$last = {}.to_json

def makeServerJson
  ret = {}
  ret["message"]  = "update"
  ret["resource"] = {}

  $resource.each do |n, r|
    if r.max > 0 
      ret["resource"][r.name] = {}
      ret["resource"][r.name]["label"]  = r.name
      ret["resource"][r.name]["incr"]   = r.incr
      ret["resource"][r.name]["max"]    = r.max
      ret["resource"][r.name]["amount"] = "%d" % r.current
    end
  end

  ret["shop"] = {}
  $buildings.each do |n, b|
    ret["shop"][n] = {}
    ret["shop"][n]["name"] = n
    ret["shop"][n]["cost"] = b["obj"].cost(b["num"])
    ret["shop"][n]["amount"] = b["num"]
  end

  ret["usercount"] = $users.count
  ret["users"] = {}
  $users.each do |u|
    ret["users"][u.trip] = {name: u.name, donated: u.donated, stolen: u.stolen}
  end

  $last = ret.to_json 
end

def broadcastMessage(who, msg)
  send = {
    "message" => "chat",
    "who"     => who, 
    "msg"     => msg 
  }.to_json
  $users.each do |u|
    u.conn.send(send)
  end
end

get '/' do
  if !request.websocket?
    erb :index
  else
    request.websocket do |ws|
      if $users.count > 100
        ws.onopen do |hs|
          $to_close << ws
        end
        ws.onmessage do |msg|
          # Doesn't matter...
        end
        ws.onclose do
          warn("Too busy!")
          $to_close.delete(ws)
        end
      else
        me = User.new(Array.new(12){[*"A".."F", *"0".."9"].sample}.join, ws)
        warn(me.name + " connected...")
        ws.onopen do |hs|
          warn(hs.to_s)
          $users << me
          setup = $last
          ws.send(setup)
          broadcastMessage("Game", me.trip + " joined the game")
        end
        ws.onmessage do |msg|
          warn(me.name + " received " + msg)
          json = JSON.parse(msg)
          type = json["type"]
          case json["action"] 
            when "chat"
              me.set_name(json["name"])
              if json["message"] != ""
                broadcastMessage(me.name, json["message"])
              end
            when "steal"
              time_left = me.is_allowed
              if (time_left < 0)
                res = $resource[type]
                if res != nil 
                  award = res.steal(json["amount"].to_i)
                  ws.send({
                    "message" => "award",
                    "type" => type,
                    "amount" => award
                  }.to_json)
                  me.update_allowed(award)
                  broadcastMessage("Game", me.name + " stole " + award.to_s + " " + type + "!")
                end
              else
                send = {
                  "message" => "chat",
                  "who"     => "Game", 
                  "msg"     => "You can't steal again for " + time_left.to_s + " seconds. Or donate " + ((time_left * 20).to_i + 1).to_s + " resources"
                }.to_json
                ws.send(send)
              end
            when "donate"
              amount = json["amount"].to_i
              res = $resource[type]
              if res != nil 
                res.donate(amount)
                me.update_allowed(amount * -1)
              end
              broadcastMessage("Game", me.name + " donated " + amount.to_s + " " + type + "!")
            when "build"
              b = json["name"]
              if $buildings[b] != nil 
                cost = 0
                $buildings[b]["obj"].cost($buildings[b]["num"]).each do |n, v|
                  cost -= v.to_i
                end
                me.update_allowed(cost)
                action = $buildings[b]["obj"].action
                action.each do |r|
                  $resource[r["type"]].build(r)
                end
                $buildings[b]["num"] += 1
                broadcastMessage("Game", me.name + " built a " + b + "!")
              end
            end
          updateAll
        end
        ws.onclose do
          warn(me.name + " websocket closed")
          $users.delete(me)
          broadcastMessage("Game", me.name + " left the game")
        end
      end
    end
  end
end

def updateAll
  makeServerJson
  EM.next_tick do
    send = $last
    $users.each do |u|
      u.conn.send(send)
    end
  end
end

Thread.new do 
  while true do
    $to_close.each do |w|
      w.close_connection([101])
    end

    $resource.each do |n, r|
      r.tick
    end

#    $user.each do |u|
#      u.tick
#    end

    updateAll

    sleep 1
  end
end
