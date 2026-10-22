import * as React from "react"

import { cn } from "../../lib/utils"

export interface InputProps
  extends React.InputHTMLAttributes<HTMLInputElement> {}

const Input = React.forwardRef<HTMLInputElement, InputProps>(
  ({ className, type, ...props }, ref) => {
    return (
      <input
        type={type}
        className={cn(
          "flex h-8 w-full rounded-lg border border-border/70 bg-black/[0.03] dark:bg-white/[0.06] px-2.5 py-1 text-xs text-foreground placeholder:text-muted-foreground/70 transition-all duration-150 shadow-[inset_0_1px_1.5px_rgba(0,0,0,0.05)] focus-visible:outline-none focus-visible:border-primary/80 focus-visible:bg-background/95 focus-visible:ring-2 focus-visible:ring-primary/25 disabled:cursor-not-allowed disabled:opacity-40",
          className
        )}
        ref={ref}
        {...props}
      />
    )
  }
)
Input.displayName = "Input"

export { Input }
