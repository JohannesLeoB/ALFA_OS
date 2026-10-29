import {
  addDays,
  addMinutes,
  addMonths,
  differenceInCalendarMonths,
  getDaysInMonth,
  setDate,
  setHours,
  setMinutes,
  startOfMonth
} from 'date-fns'

// Component Imports
import EventCalendar01 from '@/components/shadcn-studio/blocks/event-calendar-01/event-calendar-01'

// Type Imports
import type { CalendarEvent, EventColor } from '@/components/shadcn-studio/blocks/event-calendar-01/event-calendar-01'

type EventTemplate = {
  title: string
  description: string
  color: EventColor
  location?: string
  day: number
  startHour?: number
  startMinute?: number
  durationMinutes?: number
  allDay?: boolean
  spanDays?: number
}

const monthlyEventTemplates: EventTemplate[] = [
  {
    title: 'Team Sync',
    description: 'Weekly team sync and status update',
    color: 'etc',
    location: 'Conference Room A',
    day: 2,
    startHour: 10,
    durationMinutes: 60
  },
  {
    title: 'Client Call',
    description: 'Requirements walkthrough with the client',
    color: 'personal',
    location: 'Zoom',
    day: 5,
    startHour: 14,
    durationMinutes: 45
  },
  {
    title: 'Sprint Planning',
    description: 'Plan the next two-week sprint',
    color: 'business',
    location: 'Conference Room B',
    day: 8,
    startHour: 9,
    durationMinutes: 90
  },
  {
    title: 'Design Handoff',
    description: 'Hand off finalized screens to engineering',
    color: 'family',
    location: 'Design Studio',
    day: 8,
    startHour: 11,
    startMinute: 30,
    durationMinutes: 30
  },
  {
    title: 'Design Review',
    description: 'Review the latest UI mockups',
    color: 'family',
    location: 'Design Studio',
    day: 11,
    startHour: 13,
    durationMinutes: 60
  },
  {
    title: 'Budget Review',
    description: 'Monthly budget and spend review',
    color: 'holiday',
    location: 'Finance Office',
    day: 15,
    allDay: true
  },
  {
    title: 'Product Demo',
    description: 'Demo the latest release to stakeholders',
    color: 'business',
    location: 'Main Hall',
    day: 18,
    startHour: 11,
    durationMinutes: 45
  },
  {
    title: 'Innovation Workshop',
    description: 'Cross-team collaboration workshop',
    color: 'personal',
    location: 'Innovation Lab',
    day: 22,
    spanDays: 2
  },
  {
    title: 'Team Lunch',
    description: 'Casual team lunch and catch-up',
    color: 'etc',
    location: 'Downtown Cafe',
    day: 22,
    startHour: 12,
    startMinute: 30,
    durationMinutes: 45
  },
  {
    title: 'Retrospective',
    description: 'Sprint retrospective and feedback session',
    color: 'etc',
    location: 'Conference Room A',
    day: 26,
    startHour: 15,
    durationMinutes: 60
  }
]

const generateEvents = (): CalendarEvent[] => {
  const rangeStart = startOfMonth(new Date())
  const rangeEnd = new Date(2027, 2, 1)
  const monthsInRange = Math.max(1, differenceInCalendarMonths(rangeEnd, rangeStart) + 1)

  const events: CalendarEvent[] = []

  for (let monthIndex = 0; monthIndex < monthsInRange; monthIndex++) {
    const monthAnchor = addMonths(rangeStart, monthIndex)
    const daysInMonth = getDaysInMonth(monthAnchor)

    monthlyEventTemplates.forEach((template, templateIndex) => {
      if (template.day > daysInMonth) return

      const start = setMinutes(
        setHours(setDate(monthAnchor, template.day), template.startHour ?? 0),
        template.startMinute ?? 0
      )

      const end = template.allDay
        ? start
        : template.spanDays
          ? addDays(start, template.spanDays)
          : addMinutes(start, template.durationMinutes ?? 60)

      events.push({
        id: `${monthIndex}-${templateIndex}`,
        title: template.title,
        description: template.description,
        start,
        end,
        allDay: template.allDay,
        color: template.color,
        location: template.location
      })
    })
  }

  return events
}

const events = generateEvents()

const EventCalendar01Page = () => {
  return <EventCalendar01 events={events} />
}

export default EventCalendar01Page
