# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

require 'rails_helper'

# Contrato dos headers de framing (spec NDESK-60, §4.4): os Aplicativos do NChat emolduram o
# NDesk em iframe. A CSP declara a allowlist exata em `frame-ancestors`; o `X-Frame-Options`
# do Rails é removido porque não tem sintaxe de allowlist e contradiria a política.
RSpec.describe 'Frame ancestors allowlist (NDESK-60)', type: :request do
  # "a b; c d" → { 'a' => 'b', 'c' => 'd' }. Falha em diretiva duplicada em vez de sobrescrever.
  def csp_directives(header)
    header.to_s.split(';').map(&:strip).reject(&:empty?).each_with_object({}) do |directive, map|
      name, *sources = directive.split(%r{\s+})
      raise "diretiva CSP duplicada: #{name}" if map.key?(name)

      map[name] = sources.join(' ')
    end
  end

  let(:allowlist) { "'self' https://chat.newbyte.net.br https://nchat.newbyte.net.br" }

  describe 'headers padrão do Rails' do
    it 'não incluem X-Frame-Options (config e o objeto usado por ActionDispatch::Response)', :aggregate_failures do
      expect(Rails.application.config.action_dispatch.default_headers).not_to have_key('X-Frame-Options')
      expect(ActionDispatch::Response.default_headers).not_to have_key('X-Frame-Options')
    end
  end

  describe 'GET / (documento HTML do app)' do
    before { get '/' }

    it 'libera exatamente self e as duas origens do NChat, sem X-Frame-Options', :aggregate_failures do
      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq('text/html')
      expect(response.headers['Content-Security-Policy']).to be_present
      expect(csp_directives(response.headers['Content-Security-Policy'])['frame-ancestors']).to eq(allowlist)
      expect(response.headers['X-Frame-Options']).to be_nil
    end

    it 'mantém as demais diretivas no baseline do ambiente de teste', :aggregate_failures do
      # Produção acrescenta "http_type://fqdn" ao base-uri; development é report-only, acrescenta
      # 'unsafe-inline' ao script-src e http://… e ws://… ao connect-src (initializer). O nonce muda por resposta.
      expect(response.headers['Content-Security-Policy']).to be_present
      directives = csp_directives(response.headers['Content-Security-Policy'])
      script_src = directives['script-src'].to_s
      expect(script_src.scan(%r{'nonce-[^']+'}).size).to eq(1)
      expect(script_src).to match(%r{ 'nonce-[^']+'\z})
      directives['script-src'] = script_src.sub(%r{ 'nonce-[^']+'\z}, '')

      expect(directives).to eq(
        'base-uri'        => "'self'",
        'default-src'     => "'self' ws: wss: https://images.zammad.com",
        'font-src'        => "'self' data:",
        'img-src'         => '* data: blob:',
        'object-src'      => "'none'",
        'script-src'      => "'self' 'unsafe-eval'",
        'style-src'       => "'self' 'unsafe-inline'",
        'frame-src'       => 'www.youtube.com player.vimeo.com',
        'media-src'       => "'self' blob:",
        'frame-ancestors' => allowlist,
      )
    end
  end

  describe 'GET /api/v1/getting_started (JSON público)' do
    it 'recebe a mesma allowlist e também sai sem X-Frame-Options', :aggregate_failures do
      get '/api/v1/getting_started'

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq('application/json')
      expect(response.headers['Content-Security-Policy']).to be_present
      expect(csp_directives(response.headers['Content-Security-Policy'])['frame-ancestors']).to eq(allowlist)
      expect(response.headers['X-Frame-Options']).to be_nil
    end
  end
end
