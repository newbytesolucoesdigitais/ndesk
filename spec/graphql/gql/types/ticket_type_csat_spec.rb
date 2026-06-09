# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

require 'rails_helper'

RSpec.describe Gql::Types::TicketType, :aggregate_failures, type: :graphql do
  let(:query) do
    <<~QUERY
      query ticket($ticketId: ID!) {
        ticket(ticketId: $ticketId) {
          satisfactionRatable
          satisfaction { score }
        }
      }
    QUERY
  end

  let(:group)     { create(:group) }
  let(:agent)     { create(:agent, groups: [group]) }
  let(:customer)  { create(:customer) }
  let(:state)     { Ticket::State.find_by(name: 'closed') }
  let(:ticket)    { create(:ticket, group:, customer:, owner: agent, state:) }
  let(:variables) { { ticketId: gql.id(ticket) } }

  before { Setting.set('csat_integration', true) }

  context 'when the customer views a closed, unrated ticket', authenticated_as: :customer do
    it 'is ratable and exposes no rating yet' do
      gql.execute(query, variables:)
      expect(gql.result.data[:satisfactionRatable]).to be(true)
      expect(gql.result.data[:satisfaction]).to be_nil
    end
  end

  context 'when a rating already exists', authenticated_as: :customer do
    before { create(:ticket_satisfaction_rating, ticket:, customer:, score: 4) }

    it 'is no longer ratable and exposes the own rating' do
      gql.execute(query, variables:)
      expect(gql.result.data[:satisfactionRatable]).to be(false)
      expect(gql.result.data[:satisfaction][:score]).to eq(4)
    end
  end

  context 'when an agent without csat.read views a rated ticket', authenticated_as: :agent do
    before { create(:ticket_satisfaction_rating, ticket:, customer:, score: 4) }

    it 'hides the rating' do
      gql.execute(query, variables:)
      expect(gql.result.data[:satisfaction]).to be_nil
      expect(gql.result.data[:satisfactionRatable]).to be(false)
    end
  end
end
