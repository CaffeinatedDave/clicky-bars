require 'sinatra'
require 'sinatra-websocket'
require 'json'
require './models/resource'
require './models/users'

set :server, 'thin'
set :bind, '0.0.0.0'
$to_close = []

$resource = []
$users    = []

$resource << Resource.new("wood", 200, 1, 80)

# Keep this here for reasons...
$last = {}.to_json

def makeServerJson
  ret = {}
  ret["message"]  = "update"
  ret["resource"] = {}

  $resource.each do |r|
    ret["resource"][r.name] = {}
    ret["resource"][r.name]["label"]  = r.name
    ret["resource"][r.name]["incr"]   = r.incr
    ret["resource"][r.name]["max"]    = r.max
    ret["resource"][r.name]["amount"] = "%d" % r.current
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
                res = $resource.select{ |r| r.name == type}
                if res[0] != nil 
                  award = res[0].steal(json["amount"].to_i)
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
              res = $resource.select{ |r| r.name == type}
              if res[0] != nil 
                res[0].donate(amount)
                me.update_allowed(amount * -1)
              end
              broadcastMessage("Game", me.name + " donated " + amount.to_s + " " + type + "!")
            when "build"
              location = json["location"]
              case location
                when "village"
                when "camp"
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

    $resource.each do |r|
      r.tick
      new = r.rewards
      new.each do |n|
        $resource << n
      end
    end

#    $user.each do |u|
#      u.tick
#    end

    updateAll

    sleep 1
  end
end
