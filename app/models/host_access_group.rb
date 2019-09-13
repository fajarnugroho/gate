class HostAccessGroup < ApplicationRecord
  belongs_to :host_machine
  belongs_to :group

  def self.get_groups_from_machine_id machine_id
    HostAccessGroup.select("group_id").where(host_machine_id: machine_id)
  end
end
