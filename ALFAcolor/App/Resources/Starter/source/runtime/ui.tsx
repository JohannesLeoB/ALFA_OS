// Plain stand-ins for the form controls that one demo imports from its project.
// Included only in the cards that need them, because the names would clash with other sources.

function Button(props: any) {
  const { className, variant, size, ...rest } = props;
  return <button {...rest} className={cn('inline-flex items-center justify-center rounded-lg px-4 py-2 text-sm font-medium', className)} />;
}

function Input(props: any) {
  const { className, ...rest } = props;
  return <input {...rest} className={cn('h-9 w-full rounded-lg border px-3 text-sm outline-none', className)} />;
}

function Label(props: any) {
  const { className, ...rest } = props;
  return <label {...rest} className={cn('text-sm font-medium', className)} />;
}
