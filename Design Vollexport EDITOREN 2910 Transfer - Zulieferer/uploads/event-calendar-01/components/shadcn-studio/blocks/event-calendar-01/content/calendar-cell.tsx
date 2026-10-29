'use client'

// Util Imports
import { cn } from '@/lib/utils'

interface CalendarCellProps {
  time?: number
  children?: React.ReactNode
  className?: string
  onClick?: (event: React.MouseEvent<HTMLDivElement>) => void
}

export function CalendarCell({ time, children, className, onClick }: CalendarCellProps) {
  const formattedTime =
    time !== undefined
      ? `${Math.floor(time)}:${Math.round((time - Math.floor(time)) * 60)
          .toString()
          .padStart(2, '0')}`
      : undefined

  return (
    <div
      onClick={onClick}
      className={cn('flex h-full flex-col overflow-hidden px-0.5 py-1 sm:px-1', className)}
      title={formattedTime}
    >
      {children}
    </div>
  )
}
