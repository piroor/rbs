module RBS
  class Subtractor
    # TODO: Should minuend consider use directive?
    def initialize(minuend, subtrahend)
      @minuend = minuend
      @subtrahend = subtrahend

      @type_name_resolver = Resolver::TypeNameResolver.new(@subtrahend)
    end

    def call(minuend = @minuend, context: nil)
      minuend.filter_map do |decl|
        case decl
        #when AST::Declarations::AliasDecl
        when AST::Declarations::Constant
          name = absolute_typename(decl.name, context: context)
          decl unless @subtrahend.constant_decl?(name)
        #when AST::Declarations::Global
        when AST::Declarations::Class, AST::Declarations::Module, AST::Declarations::Interface
          filter_members(decl, context: context)
        else
          raise
        end
      end
    end

    private def filter_members(decl, context:)
      case decl
      when AST::Declarations::Class, AST::Declarations::Module
        # @type var children: Array[RBS::AST::Declarations::t | RBS::AST::Members::t]
        children = call(decl.each_decl.to_a, context: [context, decl.name])

        owner = absolute_typename(decl.name, context: context)
        children.concat(decl.each_member.reject { |m| member_exist?(owner, m, context: context) })

        update_decl(decl, members: children)
      when AST::Declarations::Interface
        decl
      else
        raise
      end
    end

    private def member_exist?(owner, member, context:)
      case member
      when AST::Members::MethodDefinition
        decls = owner.interface? ?
          [@subtrahend.interface_decls[owner].decl] :
          @subtrahend.class_decls[owner].decls.map { |d| d.decl }

        # TODO: performance
        decls.any? { |d|
          d.members.any? { |m|
            m.is_a?(AST::Members::MethodDefinition) && m.name == member.name && m.kind == member.kind
          }
        }
      end
    end

    private def update_decl(decl, members:)
      case decl
      when AST::Declarations::Class
        decl.class.new(name: decl.name, type_params: decl.type_params, super_class: decl.super_class,
                        annotations: decl.annotations, location: decl.location, comment: decl.comment,
                        members: members)
      when AST::Declarations::Module
        decl.class.new(name: decl.name, type_params: decl.type_params, self_types: decl.self_types,
                        annotations: decl.annotations, location: decl.location, comment: decl.comment,
                        members: members)
      when AST::Declarations::Interface
        decl.class.new(name: decl.name, type_params: decl.type_params,
                        annotations: decl.annotations, location: decl.location, comment: decl.comment,
                        members: members)
      end
    end

    private def absolute_typename(name, context:)
      while context
        ns = context[1] or raise
        name = name.with_prefix(ns.to_namespace)
        context = _ = context[0]
      end
      name.absolute!
    end
  end
end
