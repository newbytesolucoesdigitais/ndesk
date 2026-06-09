# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

require 'rails_helper'

RSpec.describe Gql::Mutations::Ticket::SatisfactionRating::Create, :aggregate_failures, type: :graphql do
  let(:query) do
    <<~QUERY
      mutation ticketSatisfactionRatingCreate($input: TicketSatisfactionRatingInput!) {
        ticketSatisfactionRatingCreate(input: $input) {
          satisfactionRating { score comment agent { id } createdAt }
          errors { message field }
        }
      }
    QUERY
  end

  let(:group)     { create(:group) }
  let(:agent)     { create(:agent, groups: [group]) }
  let(:customer)  { create(:customer) }
  let(:state)     { Ticket::State.find_by(name: 'closed') }
  let(:ticket)    { create(:ticket, group:, customer:, owner: agent, state:) }
  let(:variables) { { input: { ticketId: gql.id(ticket), score: 5, comment: 'Great!' } } }

  before { Setting.set('csat_integration', true) }

  context 'with the ticket customer', authenticated_as: :customer do
    it 'creates a rating' do
      expect { gql.execute(query, variables:) }.to change(Ticket::SatisfactionRating, :count).by(1)
      expect(gql.result.data[:satisfactionRating][:score]).to eq(5)
      expect(gql.result.data[:satisfactionRating][:agent][:id]).to eq(gql.id(agent))
    end
  end

  context 'when the ticket is open', authenticated_as: :customer do
    let(:state) { Ticket::State.find_by(name: 'open') }

    it 'returns a Forbidden error and creates nothing' do
      expect { gql.execute(query, variables:) }.not_to change(Ticket::SatisfactionRating, :count)
      expect(gql.result.error_type).to eq(Exceptions::Forbidden)
    end
  end

  context 'with a non-customer agent', authenticated_as: :agent do
    it 'is forbidden' do
      gql.execute(query, variables:)
      expect(gql.result.error_type).to eq(Exceptions::Forbidden)
    end
  end
end
