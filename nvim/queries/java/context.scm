; extends

(record_declaration
  body: (_) @context.end) @context

(interface_declaration
  body: (_) @context.end) @context

(enum_declaration
  body: (_) @context.end) @context

(annotation_type_declaration
  body: (_) @context.end) @context

(constructor_declaration
  body: (_) @context.end) @context

(compact_constructor_declaration
  body: (_) @context.end) @context

(lambda_expression
  body: (block) @context.end) @context

(while_statement
  body: (_) @context.end) @context

(do_statement
  body: (_) @context.end) @context

(try_statement
  body: (_) @context.end) @context

(try_with_resources_statement
  body: (_) @context.end) @context

(catch_clause
  body: (_) @context.end) @context

(object_creation_expression
  (class_body) @context.end) @context

(switch_rule) @context
