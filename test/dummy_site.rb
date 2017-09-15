module JekyllThemeGuidesMbland
  class DummySite
    attr_accessor :config, :layouts, :static_files, :collections, :pages
    attr_accessor :permalink_style, :source

    def initialize
      @config = { 'layouts_dir' => '_layouts' }
      @layouts = {}
      @static_files = []
      @collections = {}
      @pages = []
      @permalink_style = 'pretty'
      @source = ''
    end

    def site_payload
      {}
    end

    def converters
      []
    end
  end
end
