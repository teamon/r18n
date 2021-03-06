# encoding: utf-8
=begin
Locale to i18n support.

Copyright (C) 2008 Andrey “A.I.” Sitnik <andrey@sitnik.ru>

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU Lesser General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU Lesser General Public License for more details.

You should have received a copy of the GNU Lesser General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.
=end

require 'pathname'
require 'yaml'

module R18n
  # Information about locale (language, country and other special variant
  # preferences). Locale was named by RFC 3066. For example, locale for French
  # speaking people in Canada will be +fr_CA+.
  #
  # Locale files is placed in <tt>locales/</tt> dir in YAML files.
  #
  # Each locale has +sublocales+ – often known languages for people from this
  # locale. For example, many Belorussians know Russian and English. If there
  # is’t translation for Belorussian, it will be searched in Russian and next in
  # English translations.
  #
  # == Usage
  #
  # Get Russian locale and print it information
  #
  #   ru = R18n::Locale.load('ru')
  #   ru['title']        #=> "Русский"
  #   ru['code']         #=> "ru"
  #   ru['direction']    #=> "ltr"
  #
  # == Available data
  #
  # * +code+: locale RFC 3066 code;
  # * +title+: locale name on it language;
  # * +direction+: writing direction, +ltr+ or +rtl+ (for Arabic and Hebrew);
  # * +sublocales+: often known languages for people from this locale;
  # * +include+: locale code to include it data, optional.
  #
  # You can see more available data about locale in samples in
  # <tt>locales/</tt> dir.
  class Locale
    LOCALES_DIR = Pathname(__FILE__).dirname.expand_path + '../../locales/'

    # All available locales
    def self.available
      Dir.glob(File.join(LOCALES_DIR, '*.yml')).map do |i|
        File.basename(i, '.yml')
      end
    end

    # Is +locale+ has info file
    def self.exists?(locale)
      File.exists?(File.join(LOCALES_DIR, locale + '.yml'))
    end

    # Load locale by RFC 3066 +code+
    def self.load(code)
      code.delete! '/'
      code.delete! '\\'
      code.delete! ';'
      
      return UnsupportedLocale.new(code) unless exists? code
      
      data = {}
      klass = R18n::Locale
      default_loaded = false
      
      while code and exists? code
        file = LOCALES_DIR + "#{code}.yml"
        default_loaded = true if I18n.default == code
        
        if R18n::Locale == klass and File.exists? LOCALES_DIR + "#{code}.rb"
          require LOCALES_DIR + "#{code}.rb"
          klass = eval 'R18n::Locales::' + code.capitalize
        end
        
        loaded = YAML.load_file(file)
        code = loaded['include']
        data = Utils.deep_merge! loaded, data
      end
      
      unless default_loaded
        code = I18n.default
        while code and exists? code
          loaded = YAML.load_file(LOCALES_DIR + "#{code}.yml")
          code = loaded['include']
          data = Utils.deep_merge! loaded, data
        end
      end
      
      klass.new(data)
    end
    
    attr_reader :data

    # Create locale object with locale +data+.
    #
    # This is internal a constructor. To load translation use
    # <tt>R18n::Translation.load(locales, translations_dir)</tt>.
    def initialize(data)
      @data = data
    end

    # Get information about locale
    def [](name)
      @data[name]
    end

    # Is another locale has same code
    def ==(locale)
      @data['code'] == locale['code']
    end

    # Human readable locale code and title
    def inspect
      "Locale #{@data['code']} (#{@data['title']})"
    end
    
    # Returns the integer in String form, according to the rules of the locale.
    # It will also put real typographic minus.
    def format_integer(integer)
      str = integer.to_s
      str[0] = '−' if 0 > integer # Real typographic minus
      group = @data['numbers']['group_delimiter']
      
      str.gsub(/(\d)(?=(\d\d\d)+(?!\d))/) do |match|
        match + group
      end
    end
    
    # Returns the float in String form, according to the rules of the locale.
    # It will also put real typographic minus.
    def format_float(float)
      decimal = @data['numbers']['decimal_separator']
      self.format_integer(float.to_i) + decimal + float.to_s.split('.').last
    end
    
    # Same that <tt>Time.strftime</tt>, but translate months and week days
    # names. In +time+ you can use Time, DateTime or Date object. In +format+
    # you can use String with standart +strftime+ format (see
    # <tt>Time.strftime</tt> docs) or Symbol with format from locale file
    # (<tt>:month</tt>, <tt>:time</tt>, <tt>:date</tt>, <tt>:short_data</tt>,
    # <tt>:long_data</tt>, <tt>:datetime</tt>, <tt>:short_datetime</tt> or
    # <tt>:long_datetime</tt>).
    def strftime(time, format)
      if format.is_a? Symbol
        if :month == format
          return @data['months']['standalone'][time.month - 1]
        end
        format = @data['formats'][format.to_s]
      end
      
      translated = ''
      format.scan(/%[EO]?.|./o) do |c|
        case c.sub(/^%[EO]?(.)$/o, '%\\1')
        when '%A'
          translated << @data['week']['days'][time.wday]
        when '%a'
          translated << @data['week']['abbrs'][time.wday]
        when '%B'
          translated << @data['months']['names'][time.month - 1]
        when '%b'
          translated << @data['months']['abbrs'][time.month - 1]
        when '%p'
          translated << if time.hour < 12
            @data['time']['am']
          else
            @data['time']['pm']
          end
        else
          translated << c
        end
      end
      time.strftime(translated)
    end

    # Return pluralization type for +n+ items. This is simple form. For special
    # cases you can replace it in locale’s class.
    def pluralize(n)
      case n
      when 0
        0
      when 1
        1
      else
        'n'
      end
    end
  end
end
