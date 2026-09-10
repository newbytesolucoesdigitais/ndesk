# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

require 'rails_helper'

# Contrato dos ajustes de `config.load_defaults 8.1` (spec NDESK-45, §2.5).
# Se um default for revertido de propósito em config/application.rb, o exemplo
# correspondente muda junto, com o motivo registrado na spec da task.
RSpec.describe 'Rails 8.1 framework defaults' do # rubocop:disable RSpec/DescribeClass
  let(:config) { Rails.application.config }

  it 'loads the 8.1 defaults' do
    expect(config.loaded_config_version.to_s).to eq('8.1')
  end

  it 'keeps yjit disabled in the test environment (8.1 default: enabled only outside local envs)' do
    expect(config.yjit).to be(false)
  end

  it 'does not escape HTML entities in JSON responses' do
    expect(config.action_controller.escape_json_responses).to be(false)
  end

  it 'raises on path-relative redirects' do
    expect(config.action_controller.action_on_path_relative_redirect).to eq(:raise)
  end

  it 'raises on order-dependent finders without order columns' do
    expect(config.active_record.raise_on_missing_required_finder_order_columns).to be(true)
  end

  it 'does not escape JS line/paragraph separators in JSON' do
    expect(config.active_support.escape_js_separators_in_json).to be(false)
  end

  it 'tracks template dependencies with the ruby tracker' do
    expect(config.action_view.render_tracker).to eq(:ruby)
  end

  it 'omits autocomplete="off" on generated hidden fields' do
    expect(config.action_view.remove_hidden_field_autocomplete).to be(true)
  end

  describe 'ActiveSupport::JSON.encode' do
    it 'keeps U+2028 and U+2029 literal' do
      expect(ActiveSupport::JSON.encode("a\u2028b\u2029c")).to eq("\"a\u2028b\u2029c\"")
    end
  end

  describe 'join models with composite primary keys' do
    # Relações vazias por coluna NOT NULL: o finder roda sem depender de seeds.
    it 'allows order-dependent finders on UserGroup and RoleGroup', :aggregate_failures do
      expect { UserGroup.where(user_id: nil).first }.not_to raise_error
      expect { RoleGroup.where(role_id: nil).last }.not_to raise_error
    end
  end
end
