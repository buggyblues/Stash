import * as React from "react"
import { cva, type VariantProps } from "class-variance-authority"

import { cn } from "../../lib/utils"

const badgeVariants = cva(
  "inline-flex items-center rounded-full border px-2 py-0.5 text-[11px] font-medium transition-all duration-150 select-none focus:outline-none focus:ring-2 focus:ring-ring focus:ring-offset-1",
  {
    variants: {
      variant: {
        default:
          "border-transparent bg-primary text-primary-foreground shadow-[inset_0_1px_0_0_rgba(255,255,255,0.3),0_1px_2px_rgba(0,0,0,0.1)] hover:brightness-105",
        secondary:
          "border-border/50 bg-secondary/70 backdrop-blur-sm text-secondary-foreground hover:bg-secondary",
        destructive:
          "border-transparent bg-destructive text-destructive-foreground shadow-[inset_0_1px_0_0_rgba(255,255,255,0.25)] hover:brightness-105",
        outline:
          "border-border/60 bg-transparent text-foreground hover:bg-muted/50",
        glass:
          "border-border/40 bg-card/50 backdrop-blur-md text-foreground shadow-[inset_0_1px_0_0_rgba(255,255,255,0.4)]",
      },
    },
    defaultVariants: {
      variant: "default",
    },
  }
)

export interface BadgeProps
  extends React.HTMLAttributes<HTMLDivElement>,
    VariantProps<typeof badgeVariants> {}

function Badge({ className, variant, ...props }: BadgeProps) {
  return (
    <div className={cn(badgeVariants({ variant }), className)} {...props} />
  )
}

export { Badge, badgeVariants }
