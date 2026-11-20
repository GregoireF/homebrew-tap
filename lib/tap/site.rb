# typed: strict
# SPDX-License-Identifier: MIT OR Apache-2.0
# frozen_string_literal: true

require "cgi"
require "erb"

module Tap
  # The catalog site (GitHub Pages): an index, one page per tool with every
  # install and verification command, and an Atom feed of the versions the
  # tap serves. Static files, no JavaScript, no external resources. Pure like
  # Render: built by pages.yml, never committed.
  module Site
    TEMPLATES = File.join(Render::ROOT, "templates/site").freeze
    URL = "https://gregoiref.github.io/homebrew-tap"

    module_function

    # { relative path => content }
    def files(tools, lock)
      served = tools.filter_map { |tool| (release = lock[tool.name]) && [tool, release] }
      out = { "index.html" => page("Tools", "index", served:) }
      served.each do |tool, release|
        out["#{tool.name}/index.html"] = page(tool.name, "tool", tool:, release:)
      end
      out["feed.xml"] = feed(served)
      out[".nojekyll"] = ""
      out
    end

    def page(title, template, **locals)
      body = render(template, **locals)
      render("layout", title:, body:, depth: (template == "index") ? "" : "../")
    end

    def render(template, **locals)
      erb = ERB.new(File.binread(File.join(TEMPLATES, "#{template}.html.erb")).force_encoding("UTF-8"),
                    trim_mode: "-")
      # The template sees each local as a method, plus h() for HTML escaping.
      context = Object.new
      locals.each { |key, value| context.define_singleton_method(key) { value } }
      context.define_singleton_method(:h) { |text| CGI.escapeHTML(text.to_s) }
      erb.result(context.instance_eval { binding })
    end

    def h(text) = CGI.escapeHTML(text.to_s)

    def feed(served)
      entries = served.sort_by { |_, r| r.published.to_s }.reverse.map do |tool, release|
        updated = release.published || "1970-01-01T00:00:00Z"
        <<~XML
          <entry>
            <title>#{h tool.name} #{h release.version}</title>
            <id>#{URL}/#{h tool.name}/#{h release.version}</id>
            <link href="#{h tool.homepage}/releases/tag/#{h release.tag}"/>
            <updated>#{h updated}</updated>
            <summary>#{h tool.desc}</summary>
          </entry>
        XML
      end
      updated = served.filter_map { |_, r| r.published }.max || "1970-01-01T00:00:00Z"
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
