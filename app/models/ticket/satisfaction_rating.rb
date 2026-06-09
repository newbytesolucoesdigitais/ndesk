# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

class Ticket::SatisfactionRating < ApplicationModel
  include HasDefaultModelUserRelations

  belongs_to :ticket
  belongs_to :customer, class_name: 'User'
  belongs_to :agent,    class_name: 'User', optional: true
  belongs_to :group,    optional: true

  validates :score, presence: true, inclusion: { in: 1..5 }
  validates :ticket_id, uniqueness: { scope: :customer_id }

  # write-once: never mutate after registration
  attr_readonly :ticket_id, :customer_id, :agent_id, :score

  before_create :snapshot_agent_and_group

  private

  def snapshot_agent_and_group
    self.group_id ||= ticket.group_id
    self.agent_id ||= resolve_last_agent
  end

  # last assigned agent at registration time; fall back to the last human owner in history
  def resolve_last_agent
    return ticket.owner_id if ticket.owner_id.present? && ticket.owner_id != 1

    last = ticket.history_get
                 .select { |h| h['attribute'] == 'owner' && h['value_from'].present? }
                 .filter_map { |h| h['id_to'] || h['value_from'] }
    User.where(id: last).where.not(id: 1).last&.id
  end
end
