import '../models/chart.dart';

/// Temporary static chart catalog (until backed by API).
/// You can replace `imageUrl` with your own CDN URLs anytime.
const List<ChartItem> chartsCatalog = [
  ChartItem(
    id: 'top50_india',
    title: 'Top 50',
    subtitle: 'INDIA\nYour daily update of the most played tracks right now.',
    imageUrl: 'https://images.unsplash.com/photo-1511379938547-c1f69419868d?auto=format&fit=crop&w=900&q=80',
  ),
  ChartItem(
    id: 'top50_global',
    title: 'Top 50',
    subtitle: 'GLOBAL\nYour daily update of the most played tracks right now.',
    imageUrl: 'https://images.unsplash.com/photo-1492684223066-81342ee5ff30?auto=format&fit=crop&w=900&q=80',
  ),
  ChartItem(
    id: 'hot_hits_hindi',
    title: 'HOT HITS',
    subtitle: 'HINDI\nHottest Hindi music that India is listening to.',
    imageUrl: 'https://images.unsplash.com/photo-1524368535928-5b5e00ddc76b?auto=format&fit=crop&w=900&q=80',
  ),
  ChartItem(
    id: 'hot_hits_telugu',
    title: 'HOT HITS',
    subtitle: 'TELUGU\nTune in to the hottest tracks of Tollywood.',
    imageUrl: 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?auto=format&fit=crop&w=900&q=80',
  ),
  ChartItem(
    id: 'latest_tamil',
    title: 'Latest Tamil',
    subtitle: 'TAMIL\nNew music from Kollywood.',
    imageUrl: 'https://images.unsplash.com/photo-1526481280695-3c687fd5432c?auto=format&fit=crop&w=900&q=80',
  ),
  ChartItem(
    id: 'hot_hits_punjabi',
    title: 'HOT HITS',
    subtitle: 'PUNJABI\nCatch the hottest Punjabi tracks.',
    imageUrl: 'https://images.unsplash.com/photo-1520975916090-3105956dac38?auto=format&fit=crop&w=900&q=80',
  ),
];

