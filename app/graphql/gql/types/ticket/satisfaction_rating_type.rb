# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

module Gql::Types::Ticket
  class SatisfactionRatingType < Gql::Types::BaseObject
    include Gql::Types::Concerns::IsModelObject

    description 'A customer satisfaction rating for a ticket'

    belongs_to :agent, Gql::Types::UserType, null: true
    belongs_to :group, Gql::Types::GroupType, null: true

    field :score, Integer, null: false, description: 'Score from 1 to 5'
    field :comment, String, description: 'Optional comment provided by the customer'
  end
end
