module Sinatra
  module FormHelpers
    # FormHelpers are a suite of helper methods
    # built to make building forms in Sinatra
    # a breeze.
    #
    # link "jackhq", "http://www.jackhq.com"
    #
    # label :person, :first_name
    # input :person, :first_name
    # textarea :person, :notes
    #
    # etc.
    def form(action, method=:get, options={}, &block)
      method_input = ''
      # the docs suggest using ':create', ':update', or ':delete'
      # but you can use any symbol for the method value
      # allows for more than 3 forms on a single page
      if method.is_a? Symbol
        method_input = %Q(<input type="hidden" name="_method" value="#{method}" />)
        method = :post
      end
      action = "/#{action}" if action.is_a? Symbol

      out = tag(:form, nil, {:action => action, :method => method.to_s.upcase}.merge(options)) + method_input
      out << fieldset(action, &block) + '</form>' if block_given?
      out
    end

    def fieldset(obj, legend=nil, &block)
      raise ArgumentError, "Missing block to fieldset()" unless block_given?
      out = yield Fieldset.new(self, obj)
      '<fieldset>' + (legend.nil? ? '' : "<legend>#{fast_escape_html(legend)}</legend>") + out + '</fieldset>'
    end

    # Link to a URL
    def link(content, href=content, options={})
      tag :a, content, options.merge(:href => href)
    end

    # Form field label
    def label(obj, field, display = "", options={})
      tag :label, (display.nil? || display == '') ? titleize(field.to_s) : display, options.merge(:for => css_id(obj, field))
    end

    # Form text input.  Specify the value as :value => 'foo'
    def input(obj, field=nil, options={})
      value = param_or_default(obj, field, options[:value])
      single_tag :input, options.merge(
        :type => options[:type] || "text",
        :id => css_id(obj, field),
        :name => field.nil? ? obj : "#{obj}[#{field}]",
        :value => value
      )
    end

    # Form password input.  Specify the value as :value => 'foo'
    def password(obj, field=nil, options={})
      input(obj, field, options.merge(:type => 'password'))
    end

    # Form textarea box.
    def textarea(obj, field=nil, content='', options={})
      content = param_or_default(obj, field, content)
      tag :textarea, content, options.merge(
        :id   => css_id(obj, field),
        :name => field.nil? ? obj : "#{obj}[#{field}]"
      )
    end

    # Form submit tag.
    def submit(value='Submit', options={})
      single_tag :input, {:name => "submit", :type => "submit",
                          :value => value, :id => css_id('button', value)}.merge(options)
    end

    # Form reset tag.  Does anyone use these anymore?
    def reset(value='Reset', options={})
      single_tag :input, {:name => "reset", :type => "reset",
                          :value => value, :id => css_id('button', value)}.merge(options)
    end

    # General purpose button, usually these need JavaScript hooks.
    def button(value, options={})
      single_tag :input, {:name => "button", :type => "button",
                          :value => value, :id => css_id('button', value)}.merge(options)
    end

    # Form checkbox.  Specify an array of values to get a checkbox group.
    def checkbox(obj, field, values, options={})
      join = options.delete(:join) || ' '
      labs = options.delete(:label)
      vals = param_or_default(obj, field, [])
      ary = values.is_a?(Array) && values.length > 1 ? '[]' : ''
      Array(values).collect do |val|
        id, text = id_and_text_from_value(val)
        single_tag(:input, options.merge(:type => "checkbox", :id => css_id(obj, field, id),
                                         :name => "#{obj}[#{field}]#{ary}", :value => id,
                                         :checked => vals.include?(id) ? 'checked' : nil)) +
        (labs.nil? || labs == true ? label(obj, "#{field}_#{id.to_s.downcase}", text) : '')
      end.join(join)
    end

    # Form radio input.  Specify an array of values to get a radio group.
    def radio(obj, field, values, options={})
      #content = @params[obj] && @params[obj][field.to_s] == value ? "true" : ""
      # , :checked => content
      join = options.delete(:join) || ' '
      labs = options.delete(:label)
      vals = param_or_default(obj, field, [])
      Array(values).collect do |val|
        id, text = id_and_text_from_value(val)
        single_tag(:input, options.merge(:type => "radio", :id => css_id(obj, field, id),
                                         :name => "#{obj}[#{field}]", :value => id,
                                         :checked => vals.include?(id) ? 'checked' : nil)) +
        (labs.nil? || labs == true ? label(obj, "#{field}_#{id.to_s.downcase}", text) : '')
      end.join(join)
    end

    # Form select dropdown.  Currently only single-select (not multi-select) is supported.
    def select(obj, field, values, options={})
      value = param_or_default(obj, field, options[:value])
      content = ""
      Array(values).each do |val|
        id, text = id_and_text_from_value(val)
        tag_options = { :value => id }
        tag_options[:selected] = 'selected' if id == value
        content << tag(:option, text, tag_options)
      end
      tag :select, content, options.merge(:id => css_id(obj, field), :name => "#{obj}[#{field}]")
    end

    # Form hidden input.  Specify value as :value => 'foo'
    def hidden(obj, field = nil, options = {})
      input(obj, field, options.merge(:type => 'hidden'))
    end

    # Create a HTML element with an open and close tag.
    #
    # @param name [Symbol] the name of the tag.
    # @param content [String] the content of the tag.
    # @param attributes [Hash] the HTML attributes of the tag.
    #
    # @return [String] the generated HTML tag.
    #
    # @example Generate a HTML tag
    #     tag :h1, "My awesome title", class: "page-title"
    #     #=> "<h1 class=\"page-title\">My awesome title</h1>"
    #
    def tag(name, content, attributes={})
      attributes.reject!{|k,v| k==:id } unless options_preprocess( attributes )[:id?]
      attributes.reject!{|k,v| k==:id?}
      unless content.nil?
        "<#{name.to_s} #{hash_to_html_attrs(attributes)}>#{content}</#{name.to_s}>"
      else
        "<#{name.to_s} #{hash_to_html_attrs(attributes)}>"
      end
    end

    # Standard single closing tags
    # single_tag :img, :src => "images/google.jpg"
    # => <img src="images/google.jpg" />
    def single_tag(name, options={})
      options.reject!{|k,v| k==:id } unless options_preprocess( options )[:id?]
      options.reject!{|k,v| k==:id? }
      "<#{name.to_s} #{hash_to_html_attrs(options)} />"
    end

    def fast_escape_html(text)
      text.to_s.gsub(/\&/,'&amp;').gsub(/\"/,'&quot;').gsub(/>/,'&gt;').gsub(/</,'&lt;')
    end

    def titleize(text)
      text.to_s.gsub(/_+/, ' ').gsub(/\b('?[a-z])/) { $1.capitalize }
    end

    def param_or_default(obj, field, default)
      if field
        params[obj] ? params[obj][field.to_s] || default : default
      else
        params[obj] || default
      end
    end

    # Transform a Ruby hash into a HTML attribute string.
    #
    # @param options [Hash] key-value hash of the options to transform.
    #
    # @return [String] the generated HTML attribute string.
    #
    # @example Create a HTML attribute string
    #     hash_to_html_attrs href: '/some/url', id: 'some-id'
    #     #=> "href=\"/some/url\" id=\"some-id\""
    #
    def hash_to_html_attrs(options={})
      html_attrs = ""
      options.keys.sort.each do |key|
        next if options[key].nil? # do not include empty attributes
        html_attrs << %Q(#{key}="#{fast_escape_html(options[key])}" )
      end
      html_attrs.chop
    end

    def id_and_text_from_value(val)
      if val.is_a? Array
        [val.first, val.last]
      else
        [val, val]
      end
    end

    def css_id(*things)
      things.compact.map{|t| t.to_s}.join('_').downcase.gsub(/\W/,'_')
    end

    def options_preprocess(options)
      options[:id?] = true if options[:id?].nil? # set id? to true by default
      options
    end

    class Fieldset
      def initialize(parent, name)
        @parent = parent
        @name   = name.to_s.gsub(/\W+/,'')
      end

      def method_missing(meth, *args)
        @parent.send(meth, @name, *args)
      end
    end
  end

  helpers FormHelpers
end
