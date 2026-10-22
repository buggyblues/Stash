import appIcon from '../../assets/icon.png'

interface AppLogoProps {
  size?: 'sm' | 'md' | 'lg'
  className?: string
}

const sizeMap = {
  sm: 'w-10 h-10',
  md: 'w-16 h-16',
  lg: 'w-20 h-20'
}

export function AppLogo({ size = 'md', className = '' }: AppLogoProps): React.JSX.Element {
  return (
    <img
      src={appIcon}
      alt="Stash"
      className={`${sizeMap[size]} rounded-2xl ${className}`}
      draggable={false}
    />
  )
}
