# Onde ficam os arquivos das fotos (biometria).
#
# Em produção, no Blob da Square Cloud (SQUARECLOUD_API_KEY, com escopo
# blob:write). Fora de produção, sem a chave, numa pasta local, para dar para
# usar e testar sem a conta.
#
# Os dois lados respondem a upload(path, filename:, content_type:, name:, prefix:)
# -> { id:, url: } e delete(id).
module PhotoStorage
  class Error < StandardError; end

  def self.current
    return SquareCloud.new if ENV["SQUARECLOUD_API_KEY"].present?
    raise Error, "Fotos indisponíveis: a chave da Square Cloud (SQUARECLOUD_API_KEY) não está configurada." if Rails.env.production?

    Local.new
  end

  # Só letras, números, _ . - (padrão de nome e de pasta do Blob).
  def self.safe_segment(value)
    value.to_s.gsub(/[^A-Za-z0-9_.-]/, "_").gsub(/\.{2,}/, "_").sub(/\A[.-]+/, "")[0, 60].presence || "x"
  end
end
