class NodeFile < ActiveRecord::Base
  validates_presence_of :filename, :host
  validates_uniqueness_of :filename, :scope => :host
  belongs_to :node
  before_validation :assign_to_node

  def assign_to_node
    self.node = Node.find_or_create_by_name(self.host)
  end

end
