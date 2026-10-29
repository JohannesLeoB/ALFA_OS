'use client'

// React Imports
import { useMemo } from 'react'

// Third-party Imports
import { differenceInMinutes, format, getMinutes, isPast } from 'date-fns'

// Type Imports
import type { CalendarEvent } from '@/components/shadcn-studio/blocks/event-calendar-01/event-calendar-01'

// Util Imports
import { cn } from '@/lib/utils'
import {
  getBorderRadiusClasses,
  getEventColorClasses,
  getMonthViewBleedClasses,
  getMonthViewEventPaddingClasses
} from '@/components/shadcn-studio/blocks/event-calendar-01/event-calendar-01'

const formatEventTime = (date: Date) => format(date, getMinutes(date) === 0 ? 'ha' : 'h:mma').toLowerCase()

interface EventWrapperProps {
  event: CalendarEvent
  isFirstDay?: boolean
  isLastDay?: boolean
  onClick?: (e: React.MouseEvent) => void
  className?: string
  children: React.ReactNode
}

function EventWrapper({ event, isFirstDay = true, isLastDay = true, onClick, className, children }: EventWrapperProps) {
  return (
    <button
      className={cn(
        'focus-visible:border-ring focus-visible:ring-ring/50 flex h-full w-full text-left font-medium transition outline-none select-none focus-visible:ring-[3px] data-past-event:line-through',
        getEventColorClasses(event.color),
        getBorderRadiusClasses(isFirstDay, isLastDay),
        className
      )}
      data-calendar-event
      data-past-event={isPast(event.end) || undefined}
      onClick={onClick}
    >
      {children}
    </button>
  )
}

interface EventItemProps {
  event: CalendarEvent
  view: 'month' | 'week' | 'day'
  onClick?: (e: React.MouseEvent) => void
  showTime?: boolean
  isFirstDay?: boolean
  isLastDay?: boolean
  spansLeft?: boolean
  spansRight?: boolean
  children?: React.ReactNode
  className?: string
}

export function EventItem({
  event,
  view,
  onClick,
  showTime,
  isFirstDay = true,
  isLastDay = true,
  spansLeft = false,
  spansRight = false,
  children,
  className
}: EventItemProps) {
  const durationMinutes = useMemo(() => differenceInMinutes(event.end, event.start), [event.start, event.end])

  const getEventTime = () => {
    if (event.allDay) return 'All day'
    if (durationMinutes < 45) return formatEventTime(event.start)

    return `${formatEventTime(event.start)} - ${formatEventTime(event.end)}`
  }

  if (view === 'month') {
    const monthContent =
      children ??
      (isFirstDay ? (
        <span className='truncate'>
          {!event.allDay && (
            <span className='truncate font-normal opacity-70 sm:text-[11px]'>{formatEventTime(event.start)} </span>
          )}
          {event.title}
        </span>
      ) : null)

    return (
      <div className='relative mt-[var(--event-gap)] w-full'>
        <EventWrapper
          event={event}
          isFirstDay={isFirstDay}
          isLastDay={isLastDay}
          onClick={onClick}
          className={cn(
            'relative h-[var(--event-height)] w-full min-w-0 items-center overflow-hidden text-[10px] sm:text-xs',
            getMonthViewBleedClasses(spansRight),
            getMonthViewEventPaddingClasses(spansLeft, spansRight),
            className
          )}
        >
          {monthContent ? (
            <span className='relative z-10 block min-w-0 flex-1 truncate overflow-hidden'>{monthContent}</span>
          ) : (
            <span className='sr-only'>{event.title}</span>
          )}
        </EventWrapper>
      </div>
    )
  }

  return (
    <EventWrapper
      event={event}
      isFirstDay={isFirstDay}
      isLastDay={isLastDay}
      onClick={onClick}
      className={cn(
        'px-1 py-1 backdrop-blur-md sm:px-2',
        durationMinutes < 45 ? 'items-center' : 'flex-col',
        view === 'week' ? 'text-[10px] sm:text-xs' : 'text-xs',
        className
      )}
    >
      {durationMinutes < 45 ? (
        <div className='truncate'>
          {event.title} {showTime && <span className='opacity-70'>{formatEventTime(event.start)}</span>}
        </div>
      ) : (
        <>
          <div className='truncate font-medium'>{event.title}</div>
          {showTime && <div className='truncate font-normal opacity-70 sm:text-[11px]'>{getEventTime()}</div>}
        </>
      )}
    </EventWrapper>
  )
}
