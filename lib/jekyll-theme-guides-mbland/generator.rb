require_relative './breadcrumbs'
require_relative './generated_pages'
require_relative './namespace_flattener'

require 'jekyll'

module JekyllThemeGuidesMbland
  class Generator < ::Jekyll::Generator
    def generate(site)
      GeneratedPages.generate_pages_from_navigation_data(site)
      pages = site.collections['pages']
      docs = (pages.nil? ? [] : pages.docs) + site.pages
      Breadcrumbs.generate(site, docs)
      NamespaceFlattener.flatten_url_namespace(site, docs)
    end
  end
end
