"""
Author: Ahmet Aksoy
Date: 2026-03-03
Revision Date: 2026-03-03
Mojo version no: 0.26.1
"""

from python import Python
from collections import Dict

def get_news():
   
    var rss_urls = ["https://news.google.com/rss?hl=en-US&gl=US&ceid=US:en",
                    "https://news.google.com/rss?hl=en-GB&gl=GB&ceid=GB:en",
                    "https://news.google.com/rss?hl=tr&gl=TR&ceid=TR:tr"
    ]


    feedparser = Python.import_module("feedparser")

    try:
        for rss_url in rss_urls:
            feed = feedparser.parse(rss_url)
            articles = feed.entries[:10]  # İlk 10 haberi al
            print(" # of news: {}: ",len(articles))
            all_news = [{"title": article.get('title', 'No title'), "url": article.get('link', '#')} for article in articles]
            if len(all_news)>0:
                for news in all_news:
                    print(news['title'])
                    # print(news['url'])
    except:
        print("Error")

fn main() raises:
    get_news()

        
