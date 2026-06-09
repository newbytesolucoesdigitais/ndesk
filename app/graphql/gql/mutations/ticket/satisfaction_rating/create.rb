# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

module Gql::Mutations
  class Ticket::SatisfactionRating::Create < BaseMutation
    description 'Create a customer satisfaction rating for a ticket.'

    argument :input, Gql::Types::Input::Ticket::SatisfactionRatingInputType, description: 'The rating data'

    field :satisfaction_rating, Gql::Types::Ticket::SatisfactionRatingType, description: 'The created rating.'

    def resolve(input:)
      rating = ::Ticket::SatisfactionRating.new(
        ticket:   input[:ticket],
        customer: context.current_user,
        score:    input[:score],
        comment:  comment_value(input[:comment]),
      )

      authorize!(rating)
      rating.save!

      { satisfaction_rating: rating }
    rescue ActiveRecord::RecordInvalid => e
      error_response({ message: e.message })
    end

    private

    # Use the policy directly so the custom Exceptions::Forbidden (with its
    #   specific message) is surfaced, instead of the generic Pundit error.
    def authorize!(rating)
      policy = ::Ticket::SatisfactionRatingPolicy.new(context.current_user, rating)
      return if policy.create?

      raise policy.custom_exception || Exceptions::Forbidden, __('Not authorized')
    end

    def comment_value(comment)
      return comment if Setting.get('csat_comment') != 'off'

      nil
    end
  end
end
