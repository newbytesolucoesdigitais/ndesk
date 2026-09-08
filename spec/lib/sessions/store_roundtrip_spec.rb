# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

require 'rails_helper'

# O store de sessão serializa com to_json (encoder global do Active Support) e lê
# com JSON.parse. Com `escape_js_separators_in_json = false` os bytes gravados
# mudam; o valor lido não pode mudar (spec NDESK-45, §2.5).
RSpec.describe Sessions, 'store round-trip with Rails 8.1 JSON defaults' do # rubocop:disable RSpec/SpecFilePathFormat
  let(:client_id) { "framework-defaults-#{SecureRandom.hex(4)}" }
  let(:note)      { "a\u2028b\u2029c <>&" }

  after { described_class.destroy(client_id) }

  it 'preserves U+2028, U+2029 and HTML characters through create/get' do
    described_class.create(client_id, { 'id' => 1, 'note' => note }, { type: 'websocket' })

    expect(described_class.get(client_id)[:user]['note']).to eq(note)
  end
end
