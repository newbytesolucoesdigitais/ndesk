import * as Types from '#shared/graphql/types.ts';

import gql from 'graphql-tag';
export const SatisfactionRatingAttributesFragmentDoc = gql`
    fragment satisfactionRatingAttributes on TicketSatisfactionRating {
  score
  comment
  agent {
    id
    fullname
  }
  createdAt
}
    `;