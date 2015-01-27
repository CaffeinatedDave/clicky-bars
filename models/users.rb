require './models/resource'
require './models/building'

class User
  attr_reader :trip, :name, :allowed, :state, :conn, :donated, :stolen

  def initialize(trip, socket)
    @trip    = trip
    @name    = trip
    @allowed = Time.now
    @conn    = socket
    @donated = 0
    @stolen  = 0

    @camp    = {}
    @camp["resources"] = {}
    @camp["buildings"] = {}
  end

  def set_name(name)
    if name != ""
      @name = name
    end
  end

  def tick
    @camp["buildings"].each do |b|
      # I don't know...      
    end
  end

  def update_allowed(amount)
    if (amount >= 0)
      @stolen  += amount
      @allowed = Time.now + 1 + amount/20
    else
      @donated -= amount
      @allowed = @allowed + amount/20
    end
  end

  def is_allowed
    @allowed - Time.now
  end

  def saveState(thing) 
    
  end

  def getState
    state = {}
    camp["resources"].each do |r|
      state["resources"][r.name] = {
        label: r.name,
        current: r.current,
        max: r.max
      }
    end
  end
end
