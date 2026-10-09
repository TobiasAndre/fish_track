# Chaves do Active Record Encryption (usado para guardar o client secret e o
# refresh token do Google Drive cifrados no banco).
#
# Derivadas do secret_key_base, para não depender de chaves extras nas
# credentials. Podem ser trocadas por variáveis de ambiente; quem trocar precisa
# reconectar o Google Drive, porque os valores já cifrados deixam de abrir.
Rails.application.config.to_prepare do
  next if Rails.application.credentials.dig(:active_record_encryption, :primary_key).present?

  key_generator = Rails.application.key_generator

  ActiveRecord::Encryption.configure(
    primary_key: ENV["AR_ENCRYPTION_PRIMARY_KEY"] || key_generator.generate_key("active_record_encryption/primary_key", 32).unpack1("H*"),
    deterministic_key: ENV["AR_ENCRYPTION_DETERMINISTIC_KEY"] || key_generator.generate_key("active_record_encryption/deterministic_key", 32).unpack1("H*"),
    key_derivation_salt: ENV["AR_ENCRYPTION_KEY_DERIVATION_SALT"] || key_generator.generate_key("active_record_encryption/key_derivation_salt", 32).unpack1("H*")
  )
end
