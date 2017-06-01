typedef int stack_state;

define_stack_type(ss_stack, stack_state, 0);

static inline int stack_state_push(stack_state *ss, int bit)
{
  bit = bit ? 1 : 0;
  *ss = (*ss << 1) | bit;
  return bit;
}

static inline int stack_state_pop(stack_state *ss)
{
  int bit = *ss & 1;
  *ss >>= 1;
  return bit;
}

static inline int stack_state_lexpop(stack_state *ss)
{
  return stack_state_push(ss, stack_state_pop(ss) || stack_state_pop(ss));
}

static inline int stack_state_active(stack_state *ss)
{
  return *ss & 1;
}
