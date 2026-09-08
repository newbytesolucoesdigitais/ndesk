# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

require 'rails_helper'

# Rails 8.1: `action_on_path_relative_redirect = :raise` (spec NDESK-45, §2.5).
# Controller anônimo derivado de ActionController::Base: não passa pelo
# ApplicationController::HandlesErrors, então a exceção chega ao exemplo.
RSpec.describe ActionController::Base, type: :controller do # rubocop:disable RSpec/SpecFilePathFormat
  controller do
    def index
      redirect_to 'relative-target'
    end
  end

  it 'raises PathRelativeRedirectError for a target without leading slash or scheme' do
    expect { get :index }.to raise_error(ActionController::Redirecting::PathRelativeRedirectError)
  end
end
