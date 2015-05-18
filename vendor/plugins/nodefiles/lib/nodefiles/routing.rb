module Nodefiles #:nodoc:
  module Routing #:nodoc:
    module MapperExtensions
      def nodefiles
        @set.add_route("/nodefiles", {:controller => "nodefiles", :action => "nodefiles"})
      end
    end
  end
end

ActionController::Routing::RouteSet::Mapper.send :include, Nodefiles::Routing::MapperExtensions
