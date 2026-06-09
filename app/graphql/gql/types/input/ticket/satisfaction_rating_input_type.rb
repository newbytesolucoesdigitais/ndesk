# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

module Gql::Types::Input::Ticket
  class SatisfactionRatingInputType < Gql::Types::BaseInputObject
    description 'Input for creating a ticket satisfaction rating'

    argument :ticket_id, GraphQL::Types::ID, required: true, description: 'The ticket being rated', loads: Gql::Types::TicketType
    argument :score, GraphQL::Types::Int, required: true, description: 'Score from 1 to 5'
    argument :comment, String, required: false, description: 'Optional comment'
  end
end
