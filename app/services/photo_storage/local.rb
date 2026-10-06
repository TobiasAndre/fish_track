require "fileutils"

module PhotoStorage
  # Fotos numa pasta local (desenvolvimento e testes, sem a conta da Square
  # Cloud). Em desenvolvimento ficam em public/dev_uploads, servidas pelo próprio
  # Rails.
  class Local
    def initialize(root: Rails.env.test? ? Rails.root.join("tmp/test_uploads") : Rails.public_path.join("dev_uploads"), url_prefix: "/dev_uploads")
      @root = Pathname(root)
      @url_prefix = url_prefix
    end

    def upload(path, filename:, content_type:, name:, prefix:)
      extension = File.extname(filename.to_s).downcase.presence || ".bin"
      relative = File.join(prefix.to_s, "#{PhotoStorage.safe_segment(name)}-#{SecureRandom.hex(8)}#{extension}")

      FileUtils.mkdir_p(@root.join(File.dirname(relative)))
      FileUtils.cp(path, @root.join(relative))

      { id: "local/#{relative}", url: "#{@url_prefix}/#{relative}" }
    end

    def delete(id)
      relative = id.to_s.delete_prefix("local/")
      target = @root.join(relative).expand_path
      FileUtils.rm_f(target) if target.to_s.start_with?(@root.expand_path.to_s)
      true
    end
  end
end
