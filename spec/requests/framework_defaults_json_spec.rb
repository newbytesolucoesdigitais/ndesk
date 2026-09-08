# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

require 'rails_helper'

# Rails 8.1: `escape_json_responses = false` e `escape_js_separators_in_json = false`
# (spec NDESK-45, §2.5). O cliente faz JSON.parse; o que muda são os bytes no fio.
# Ticket#check_title só normaliza \s|\t|\r, que não casam U+2028/U+2029.
RSpec.describe 'JSON responses with Rails 8.1 defaults', type: :request do
  let(:title)   { "Tag <b>&amp;</b> \u2028line\u2029para" }
  let!(:ticket) { create(:ticket, title: title) }
  let(:agent)   { create(:agent, groups: Group.all) }

  before { authenticated_as(agent) }

  it 'sends HTML characters, U+2028 and U+2029 unescaped in the raw body', :aggregate_failures do
    get "/api/v1/tickets/#{ticket.id}", as: :json

    expect(response).to have_http_status(:ok)
    expect(json_response['title']).to eq(title)
    expect(response.body).to include('<b>&amp;</b>').and include("\u2028").and include("\u2029")
    expect(response.body).not_to include('\u003c')
    expect(response.body).not_to include('\u2028')
    expect(response.body).not_to include('\u2029')
  end
end
