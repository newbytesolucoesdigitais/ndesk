# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

require 'rails_helper'

RSpec.describe ActiveRecord::Locking::Pessimistic do
  let!(:ticket) { create(:ticket) }

  def set_old_ticket_store

    # set old store
    ActiveRecord::Base.connection.execute("UPDATE tickets SET preferences = '--- !ruby/hash:ActiveSupport::HashWithIndifferentAccess
 form: !ruby/hash:ActiveSupport::HashWithIndifferentAccess
   remote_ip: 111.111.98.123
   fingerprint_md5: 66638aad396c60ecb24f96de1e59d111' WHERE id = #{ticket.id}")

    # kill cache
    Rails.cache.clear

    # reload ticket and make sure that the store is deserialized
    ticket.reload.preferences
  end

  it 'does raise the error for changes before lock' do
    ticket.updated_at = Time.zone.now
    expect { ticket.lock! }.to raise_error(RuntimeError)
  end

  it 'does not raise the error if the store has changes but only structure changed' do
    set_old_ticket_store
    expect do
      ticket.lock!
      ticket.update(title: SecureRandom.uuid)
    end.not_to raise_error
  end

  # Rails 8.1: lock! levanta ReadOnlyError em while_preventing_writes. O patch de
  # config/initializers/active_record_lock_issue_3664.rb tem um ramo que retorna
  # antes de chamar o lock! original; o guard precisa valer também nesse ramo.
  it 'raises ReadOnlyError while preventing writes even when only the store structure changed' do
    set_old_ticket_store

    ActiveRecord::Base.while_preventing_writes do
      expect { ticket.lock! }.to raise_error(ActiveRecord::ReadOnlyError)
    end
  end

  # O ramo acima ainda passa pela segunda guarda do 8.1 (ActiveRecord::Relation#exec_queries,
  # `lock_value && current_preventing_writes`), porque reload(lock: true) é uma lock query.
  # Com cláusula falsy não há lock query, então só o guard no topo do lock! sustenta o
  # contrato do upstream, que levanta para qualquer argumento.
  it 'raises ReadOnlyError while preventing writes even when the lock clause is falsy' do
    set_old_ticket_store

    ActiveRecord::Base.while_preventing_writes do
      expect { ticket.lock!(false) }.to raise_error(ActiveRecord::ReadOnlyError)
    end
  end
end
