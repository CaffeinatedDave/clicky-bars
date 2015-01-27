require './models/resource'

class Building
  attr_reader :name, :baseCost, :factor, :action

  def initialize(name, baseCost, factor, action)
    @name     = name
    @baseCost = baseCost
    @factor   = factor
    @action   = action
  end

  def cost(num_owned) 
    cost = {}
    @baseCost.each do |r|
      cost["name"]   = r.name 
      cost["amount"] = r.amount * @factor
    end
    return cost
  end
end
