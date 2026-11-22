# typed: strict
# SPDX-License-Identifier: MIT OR Apache-2.0
# frozen_string_literal: true

require "cgi"

module Tap
  module Targets
    # The catalog site (GitHub Pages): an index, one page per tool with every
    # install and verification command, and an Atom feed of the versions the
    # tap serves. Static files, no JavaScript, no external resources. Written
    # to the Pages artifact by pages.yml, never committed.
    module Pages
      GLOBS = [].freeze
      URL = "https://gregoiref.github.io/homebrew-tap"
      EPOCH = "1970-01-01T00:00:00Z"
      LAYOUT = Targets.template("site/layout.html.erb").freeze
      INDEX = Targets.template("site/index.html.erb").freeze
      TOOL = Targets.template("site/tool.html.erb").freeze

      module_function

      def files(catalog)
        served = catalog.served
        out = { "index.html" => page("Tools", INDEX, "", served:) }
        served.each do |tool, release|
          out["#{tool.name}/index.html"] = page(tool.name, TOOL, "../", tool:, release:,
                                                badges: Badges.markdown(tool))
        end
        out["feed.xml"] = feed(served)
        out[".nojekyll"] = ""
        out
      end

      def page(title, template, depth, **locals)
        render(LAYOUT, title:, depth:, body: render(template, **locals))
      end

      # The template sees each local as a method, plus h() for HTML escaping.
      def render(template, **locals)
        context = Object.new
        locals.each { |key, value| context.define_singleton_method(key) { value } }
        context.define_singleton_method(:h) { |text| CGI.escapeHTML(text.to_s) }
        template.result(context.instance_eval { binding })
      end

      def h(text) = CGI.escapeHTML(text.to_s)

      def feed(served)
        entries = served.sort_by { |_, r| r.published.to_s }.reverse.map do |tool, release|
          <<~XML
            <entry>
              <title>#{h tool.name} #{h release.version}</title>
              <id>#{URL}/#{h tool.name}/#{h release.version}</id>
              <link href="#{h tool.homepage}/releases/tag/#{h release.tag}"/>
              <updated>#{h(release.published || EPOCH)}</updated>
              <summary>#{h tool.desc}</summary>
            </entry>
          XML
        end
        updated = served.filter_map { |_, r| r.published }.max || EPOCH
        <<~XML
          <?xml version="1.0" encoding="utf-8"?>
          <feed xmlns="http://www.w3.org/2005/Atom">
          <title>GregoireF tap: new versions</title>
          <id>#{URL}/feed.xml</id>
          <link href="#{URL}/"/>
          <link rel="self" href="#{URL}/feed.xml"/>
          <updated>#{updated}</updated>
          #{entries.join}</feed>
        XML
      end
    end
  end
end
