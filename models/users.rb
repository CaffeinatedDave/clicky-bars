class User
  attr_reader :trip, :name, :allowed

  def initialize(trip)
    @trip    = trip
    @name    = trip
    @allowed = Time.now
  end

  def update_allowed 
    @allowed = Time.now + 5
  end

  def is_allowed?
    if Time.now > @allowed
      return true
    else
      return false
    end
  end
end
