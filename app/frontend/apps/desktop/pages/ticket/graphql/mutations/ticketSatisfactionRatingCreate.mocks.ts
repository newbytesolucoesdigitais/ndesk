import * as Types from '#shared/graphql/types.ts';

import * as Mocks from '#tests/graphql/builders/mocks.ts'
import * as Operations from './ticketSatisfactionRatingCreate.api.ts'
import * as ErrorTypes from '#shared/types/error.ts'

export function mockTicketSatisfactionRatingCreateMutation(defaults: Mocks.MockDefaultsValue<Types.TicketSatisfactionRatingCreateMutation, Types.TicketSatisfactionRatingCreateMutationVariables>) {
  return Mocks.mockGraphQLResult(Operations.TicketSatisfactionRatingCreateDocument, defaults)
}

export function waitForTicketSatisfactionRatingCreateMutationCalls() {
  return Mocks.waitForGraphQLMockCalls<Types.TicketSatisfactionRatingCreateMutation>(Operations.TicketSatisfactionRatingCreateDocument)
}

export function mockTicketSatisfactionRatingCreateMutationError(message: string, extensions: {type: ErrorTypes.GraphQLErrorTypes }) {
  return Mocks.mockGraphQLResultWithError(Operations.TicketSatisfactionRatingCreateDocument, message, extensions);
}
