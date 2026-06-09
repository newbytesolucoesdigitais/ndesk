import * as Types from '#shared/graphql/types.ts';

import gql from 'graphql-tag';
import { SatisfactionRatingAttributesFragmentDoc } from '../../../../../../shared/entities/ticket/graphql/fragments/satisfactionRatingAttributes.api';
import { ErrorsFragmentDoc } from '../../../../../../shared/graphql/fragments/errors.api';
import * as VueApolloComposable from '@vue/apollo-composable';
import * as VueCompositionApi from 'vue';
export type ReactiveFunction<TParam> = () => TParam;

export const TicketSatisfactionRatingCreateDocument = gql`
    mutation ticketSatisfactionRatingCreate($input: TicketSatisfactionRatingInput!) {
  ticketSatisfactionRatingCreate(input: $input) {
    satisfactionRating {
      ...satisfactionRatingAttributes
    }
    errors {
      ...errors
    }
  }
}
    ${SatisfactionRatingAttributesFragmentDoc}
${ErrorsFragmentDoc}`;
export function useTicketSatisfactionRatingCreateMutation(options: VueApolloComposable.UseMutationOptions<Types.TicketSatisfactionRatingCreateMutation, Types.TicketSatisfactionRatingCreateMutationVariables> | ReactiveFunction<VueApolloComposable.UseMutationOptions<Types.TicketSatisfactionRatingCreateMutation, Types.TicketSatisfactionRatingCreateMutationVariables>> = {}) {
  return VueApolloComposable.useMutation<Types.TicketSatisfactionRatingCreateMutation, Types.TicketSatisfactionRatingCreateMutationVariables>(TicketSatisfactionRatingCreateDocument, options);
}
export type TicketSatisfactionRatingCreateMutationCompositionFunctionResult = VueApolloComposable.UseMutationReturn<Types.TicketSatisfactionRatingCreateMutation, Types.TicketSatisfactionRatingCreateMutationVariables>;