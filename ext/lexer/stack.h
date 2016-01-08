#define define_stack_type(name, member_type, zero) \
  typedef struct name { \
    member_type *top; \
    member_type *bottom; \
    int size; /* used when growing dynamically */ \
  } name; \
  static inline void name ## _init(name *stack) { \
    member_type *buf = xmalloc(4 * sizeof(member_type)); \
    stack->size = 4; \
    stack->top  = stack->bottom = buf; \
  } \
  static inline void name ## _dealloc(name *stack) { \
    xfree(stack->bottom); \
  } \
  static inline void name ## _clear(name *stack) { \
    stack->top = stack->bottom; \
  } \
  static inline void name ## _push(name *stack, member_type item) { \
    if (stack->top == (stack->bottom + stack->size)) { \
      member_type *buf = xmalloc(stack->size * 2 * sizeof(member_type)); \
      memcpy(buf, stack->bottom, stack->size * sizeof(member_type)); \
      xfree(stack->bottom); \
      stack->top = buf + (stack->top - stack->bottom); \
      stack->bottom = buf; \
      stack->size = stack->size * 2; \
    } \
    *stack->top++ = item; \
  } \
  static inline member_type name ## _pop(name *stack) { \
    if (stack->top > stack->bottom) { \
      return *--stack->top; \
    } else { \
      return (member_type)zero; \
    } \
  } \
  static inline member_type* name ## _top(name *stack) { \
    if (stack->top > stack->bottom) \
      return stack->top - 1; \
    else \
      return NULL; \
  }
