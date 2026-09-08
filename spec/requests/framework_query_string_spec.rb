# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

require 'rails_helper'

# Rails 8.1 (independente de load_defaults): ';' deixa de separar parâmetros e
# colchetes iniciais deixam de ser descartados (spec NDESK-45, §2.5).
RSpec.describe 'Query string parsing on Rails 8.1', type: :request do
  it 'keeps ";" inside a value and "[foo]" as a literal key', :aggregate_failures do
    get '/api/v1/getting_started?a=1;b=2&[foo]=bar'

    expect(response).to have_http_status(:ok)
    expect(request.query_parameters).to include('a' => '1;b=2', '[foo]' => 'bar')
    expect(request.query_parameters).not_to include('b', 'foo')
  end
end
