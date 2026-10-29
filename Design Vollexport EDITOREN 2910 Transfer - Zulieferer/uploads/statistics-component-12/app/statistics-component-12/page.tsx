import StatisticsWithStatus, {
  type StatisticsCardProps
} from '@/components/shadcn-studio/blocks/statistics-with-status'
import { BriefcaseIcon, ReceiptIcon, PiggyBankIcon, WalletIcon } from 'lucide-react'

const statisticsData: StatisticsCardProps[] = [
  {
    title: 'Net Profit',
    value: '$38,200',
    status: 'within',
    range: '$30k - $50k',
    icon: (
      <BriefcaseIcon />
    )
  },
  {
    title: 'Operating Expenses',
    value: '$21,750',
    status: 'exceed',
    range: 'Target: $18k',
    icon: (
      <ReceiptIcon />
    )
  },
  {
    title: 'Cash Reserves',
    value: '$94,500',
    status: 'observe',
    range: '$80k - $120k',
    icon: (
      <PiggyBankIcon />
    )
  },
  {
    title: 'Budget Utilisation',
    value: '78%',
    status: 'unknown',
    range: 'Q4 Review Pending',
    icon: (
      <WalletIcon />
    )
  }
]

const StatisticsCardPreview = () => {
  return (
    <div className='py-8 sm:py-16 lg:py-24'>
      <div className='mx-auto grid max-w-7xl gap-4 px-4 sm:grid-cols-2 sm:px-6 lg:px-8 xl:grid-cols-4'>
        {statisticsData.map((card, index) => (
          <StatisticsWithStatus key={index} {...card} />
        ))}
      </div>
    </div>
  )
}

export default StatisticsCardPreview
