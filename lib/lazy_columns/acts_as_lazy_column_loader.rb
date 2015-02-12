module LazyColumns
  module ActsAsLazyColumnLoader
    extend ActiveSupport::Concern

    module ClassMethods
      def lazy_load(*columns)
        return unless table_exists?
        columns = columns.collect(&:to_s)
        exclude_columns_from_default_scope columns
        define_lazy_accessors_for columns
      end

      private

      def exclude_columns_from_default_scope(columns)
        default_scope { select((column_names - columns).map { |column_name| "#{table_name}.#{column_name}" }) }
      end

      def define_lazy_accessors_for(columns)
        columns.each { |column| define_lazy_accessor_for column, columns }
      end

      def define_lazy_accessor_for(column, lazy_columns)
        define_method column do
          unless has_attribute?(column)
            missing_columns = lazy_columns.reject { |column_name| has_attribute?(column_name) }
            fresh_record = self.class.unscoped.select(missing_columns).find(id)
            fresh_attributes = fresh_record.instance_variable_get('@attributes')
            if @attributes.is_a?(Hash)
              # Rails 3: @attributes is a Hash containing only the missing columns
              @attributes.update(fresh_attributes)
            else
              # Rails 4: @attributes is an ActiveRecord::AttributeSet
              #          @attributes.@attributes is a LazyAttributeHash which implements []=
              missing_columns.each do |column_name|
                @attributes.instance_variable_get('@attributes')[column_name] = fresh_attributes[column_name]
              end
            end
          end
          read_attribute column
        end
      end
    end
  end
end

if ActiveRecord::Base.respond_to?(:lazy_load)
  $stderr.puts "ERROR: Method `.lazy_load` already defined in `ActiveRecord::Base`. This is incompatible with LazyColumns and the plugin will be disabled."
else
  ActiveRecord::Base.send :include, LazyColumns::ActsAsLazyColumnLoader
end


