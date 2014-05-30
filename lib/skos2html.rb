# encoding: UTF-8
#
module Skos2Html
  require 'linkeddata'
  require 'logger'
  require 'builder'

  # Converts a SKOS RDF file to a bare-bones HTML file
  # readabale for humans. Rendering a HTML file consists of
  # three basic steps:
  # 1. Create a new instance of this class and specify input and output file.
  # 2. Call load_and_parse.
  # 3. Call generate_html_document.
  # 4. Call the write method.
  class Converter

    # The output buffer to which we write all HTML.
    attr_accessor :buffer

    # Initialize the class.
    #
    # @param infile [String], a filepath to a SKOS RDF/XML file
    # @param outfile [String], a filepath where the resulting file will be written (overwriting existing files)
    def initialize(infile=nil, outfile="vocab.html")
      @log = defined?(Rails) ? Rails.logger : Logger.new(STDOUT)
      @log.info("init")

      @infile = infile
      @outfile = outfile

      @default_lang = :en

      @graph = nil
      @vocabs = nil
      set_up_vocabs

      @buffer = ""
      @builder = Builder::XmlMarkup.new(:target=>@buffer, :indent=>2)

      @title = ""

    end


    # Load some basic vocabularies in order to retrieve labels
    # etc.
    def set_up_vocabs
      @vocabs = RDF::Graph.load(File.expand_path("skos.rdf", File.dirname(__FILE__)))
      @vocabs << RDF::Graph.load(File.expand_path("dcterms.rdf", File.dirname(__FILE__)))
      @vocabs << RDF::Graph.load(File.expand_path("rdf-schema.rdf", File.dirname(__FILE__)))
    end


    # Load the SKOS RDF file into a graph object.
    def load_and_parse

      if @infile
        @graph = RDF::Graph.load(@infile)
      end

    end


    def generate_html_document
      @builder.declare! :DOCTYPE, :html

      @builder.html(:lang => @default_lang) { |html|
        generate_html_head
        generate_html_body
      }
    end


    def generate_html_body
      @builder.body { |body|
        generate_conceptscheme_info
        generate_concepts
      }
    end


    def generate_html_head

      title = concept_scheme_title

      @builder.head { |head|
        head.meta(:charset => "UTF-8")
        head.title(title)
        head.meta(:name => "generator", :content => "skos2html")
        head.comment! "Edit styles and other html in this file as you like but do not change text or id-attributes."
        head.style("""
html {
    margin: auto;
    max-width: 800px;
    font-family: Helvetica, Arial, sans-serif;
}

dt {
    font-weight: bold;
    margin: 0.8em 0 0.2em 0;
}

dd {
    margin: 0;
}

dd.contributor {
    display:inline;
}

dd.contributor:after { content: ', '; }
dd.contributor:last-child:after { content: ''; }

dd.identifier {
  font-family: Consolas, 'Lucida Console', 'Courier New', sans-serif;
}

div.conceptscheme {
    border-bottom: 1px solid #aaa;
    margin: 1em 0 2em 0;
}

div.concept {
  margin: 0 0 2.5em 0;
}
                   """)
      }

    end



    def labels_for(uri)

      solutions = RDF::Query.execute(@vocabs) do
        pattern [RDF::URI.new(uri), RDF::RDFS.label, :label]
      end

      result = []

      if solutions
        solutions.each do |solution|
          # adding RDF literals
          result << solution.label
        end
      end

      return result
    end



    def string_for(obj, lang)
      # return a human readable representation of obj - for literals the literal
      # value in lang. For URI:s lookup something.

      case obj
      when String
        return obj
      when RDF::Literal
        if lang
          if obj.language == lang
            return obj.to_s
          else
            return "[Not available in #{lang}]"
          end
        else
          return obj.to_s
        end
      when RDF::URI
        # TODO: fetch it...
        return "[fetched label for #{obj.to_s}]"
      else
        @log.info("unknown class")
      end
    end



    def label_for(uri, lang)

      @log.info("label_for #{uri} #{lang}")

      labels = labels_for(uri)

      @log.info("labels: #{labels.inspect}")

      if labels
        labels.each do |label|

          @log.info("label: #{label}")

          if label.language == lang
            return label.value
          end
        end
      end
    end


    def generate_conceptscheme_info

      conceptschemes = RDF::Query.execute(@graph) do
        pattern [:scheme, RDF.type, RDF::SKOS.ConceptScheme]
      end


      @log.info("Concept scheme count #{conceptschemes.size}")


      if conceptschemes.size == 1

        scheme = conceptschemes[0]
        @log.info("Concept scheme " + scheme.scheme)

        scheme_info = RDF::Query.execute(@graph) do
          pattern [scheme.scheme, :predicate, :object]
        end

        title = ""
        description = ""
        creators = []
        contributors = []
        version = nil

        # get values
        scheme_info.each do |solution|

          case solution.predicate
          when "http://purl.org/dc/terms/title", "http://www.w3.org/2000/01/rdf-schema#label"
            title = string_for(solution.object, @default_lang)
          when "http://purl.org/dc/terms/description"
            description = string_for(solution.object, @default_lang)
          when "http://purl.org/dc/terms/contributor"
            contributors << string_for(solution.object, nil)
          when "http://purl.org/dc/terms/creator"
            creators << string_for(solution.object, nil)
          end

        end

        @builder.div(:class => "conceptscheme") { |html|

          html.h1(title)

          html.dl { |html|

            html.dt("Description")
            html.dd(description, "class" => "description")

            if contributors.size > 0
              html.dt("Contributors")

              contributors.each do |item|
                html.dd(item, "class" => "contributor")
              end
            end

            if creators.size > 0
              html.dt("Creators")

              creators.each do |item|
                html.dd(item, "class" => "creator")
              end
            end

            html.dt("Identifier")
            html.dd(scheme.scheme, :class => "identifier")

          }
        }

      else
        @log.info("Concept scheme count wrong. Expected 1 was " + conceptschemes.size)
      end

    end



    def generate_concepts
      concepts = RDF::Query.execute(@graph) do
        pattern [:concept_uri, RDF.type, RDF::SKOS.Concept]
      end

      @log.info("Concept count: #{concepts.size}")

      concepts.each do |concept|
        generate_concept(concept.concept_uri)
      end

    end




    # Get the title of this vocabulary for use in the HTML
    # title element
    def concept_scheme_title

      # Possible properties
      title_properties = ["http://purl.org/dc/terms/title",
                          "http://www.w3.org/2000/01/rdf-schema#label",
                          "http://www.w3.org/2004/02/skos/core#prefLabel"]

      title = ""

      conceptschemes = RDF::Query.execute(@graph) do
        pattern [:scheme, RDF.type, RDF::SKOS.ConceptScheme]
      end

      if conceptschemes.size == 1

        scheme = conceptschemes[0]
        @log.info("Looking for title for " + scheme.scheme)

        scheme_info = RDF::Query.execute(@graph) do
          pattern [scheme.scheme, :predicate, :object]
        end

        scheme_info.each do |solution|

          case solution.predicate.to_s
          when *title_properties
            title = solution.object.value
          end
        end

        return title

      end

    end



    def concept_preflabel(concept_uri)

      uri = RDF::URI.new(concept_uri)

      labels = RDF::Query.execute(@graph) do
        pattern [uri, RDF::SKOS.prefLabel, :object]
      end

      labels.filter { |label| label.object.language == @default_lang }

      if labels.size > 0
        return labels[0].object.value
      else
        @log.error("Preflabel missing for #{concept_uri}")
        return ""
      end
    end



    # Generate the HTML for an individual concept.
    def generate_concept(concept_uri)

      @log.info("Generate concept #{concept_uri}")

      concept_info = RDF::Query.execute(@graph) do
        pattern [concept_uri, :predicate, :object]
      end

      preflabels = []
      altlabels = []
      definition = ""
      has_broader = nil
      has_narrower = nil
      editorialNote = nil

      concept_info.each do |solution|

        case solution.predicate
        when "http://www.w3.org/2004/02/skos/core#prefLabel"
          if solution.object.language?
            preflabels << {"lang" => solution.object.language.to_sym, "val" => solution.object.to_s}
          else
            preflabels << {"lang" => nil, "val" => solution.object.to_s}
          end
        when "http://www.w3.org/2004/02/skos/core#altLabel"
          if solution.object.language?
            altlabels << {"lang" => solution.object.language.to_sym, "val" => solution.object.to_s}
          else
            altlabels << {"lang" => nil, "val" => solution.object.to_s}
          end
        when "http://www.w3.org/2004/02/skos/core#definition"
          definition = string_for(solution.object, @default_lang)
        when "http://www.w3.org/2004/02/skos/core#editorialNote"
          editorialNote = string_for(solution.object, @default_lang)
        when "http://www.w3.org/2004/02/skos/core#broader"
          has_broader = solution.object.value
        when "http://www.w3.org/2004/02/skos/core#narrower"
          has_narrower = solution.object.value
        end

      end


      @builder.div(:id => concept_uri.fragment, :class => "concept") { |html|
        # preflabel in defaultlang
        html.h2(preflabels.detect {|label| label["lang"] == @default_lang}["val"])
        html.dl {
          html.dt("Definition", :class => "definition")
          html.dd(definition, :class => "definition")

          if altlabels.size > 0
            html.dt("Alternative labels", {:class => "altlabels"})

            altlabels.each do |label|

              if label["lang"]

                if label["lang"] != @default_lang
                  html.dd(label["val"] + "(#{label['lang']})", :lang => label["lang"], :class => "altlabel")
                else
                  html.dd(label["val"], :class => "altlabel")
                end

              else
                html.dd(label["val"], :class => "altlabel")
              end
            end
          end


          if has_broader

            has_broader_uri = has_broader

            unless has_broader.start_with?("http://")
              r = RDF::URI.new(concept_uri)
              r.fragment = has_broader[1..-1]
              has_broader_uri = r.to_s
            end

            html.dt("Has broader", :class => "broader")
            html.dd(:class => "broader") {
              html.a(concept_preflabel(has_broader_uri), :href => has_broader)
            }
          end


          if has_narrower

            has_narrower_uri = has_narrower

            unless has_narrower.start_with?("http://")
              r = RDF::URI.new(concept_uri)
              r.fragment = has_narrower[1..-1]
              has_narrower_uri = r.to_s
            end
            html.dt("Has narrower", :class => "narrower")
            html.dd(:class => "narrower") {
              html.a(concept_preflabel(has_narrower_uri), :href => has_narrower)
            }
          end

          if editorialNote
            html.dt(label_for(RDF::SKOS.editorialNote, @default_lang))
            html.dd(editorialNote, :class => "editorial_note")
          end

          html.dt("Identifier", :class => "identifier")
          html.dd(concept_uri, :class => "identifier")
        }
      }

    end



    # Write the output to disk as an UTF-8 encoded file.
    def write

      # output to disk
      File.open(@outfile, 'w:UTF-8') { |file|
        file.write(@buffer)
      }
    end

  end
end
