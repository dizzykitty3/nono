//
//  NONOTests.swift
//  NONOTests
//
//  Created by Theo on 9/17/26.
//

import Testing
@testable import NONO

struct NONOTests {

    @Test func recognizesPixivProfilesWithLanguagePrefixes() {
        let input = """
        https://www.pixiv.net/en/users/94295754
        https://pixiv.net/users/100
        https://www.pixiv.net/zh/users/200
        """
        #expect(LinkProcessor.organize(input) == """
        #
        https://pixiv.net/users/100
        https://www.pixiv.net/zh/users/200
        https://www.pixiv.net/en/users/94295754
        """)
    }

    @Test func recognizesHanimeSearchValue() {
        #expect(LinkProcessor.organize("https://hanime1.me/search?query=123") == "#\nhttps://hanime1.me/search?query=123")
    }

    @Test func recognizes18ComicSearchUsername() {
        for host in ["18comic.vip", "www.18comic.vip"] {
            for path in ["/search/photos", "/search/photos/"] {
                let url = "https://\(host)\(path)?search_query=Kawagawa&page=2"
                #expect(LinkProcessor.organize(url) == "K\n\(url)")
            }
        }
        let url = "https://18comic.vip/search/photos?search_query=Kawagawa"
        #expect(LinkProcessor.organize(url) == "K\n\(url)")
        #expect(LinkProcessor.organize("https://18comic.vip/search/photos?search_query=").hasPrefix("S\n"))
    }

    @Test func recognizesErohereSearchPath() {
        for term in ["萝莉病", "%E8%90%9D%E8%8E%89%E7%97%85"] {
            let url = "https://my.erohere.eu/search/\(term)"
            #expect(LinkProcessor.organize(url) == "L\nhttps://my.erohere.eu/search/萝莉病")
        }
        let url = "https://my.erohere.eu/search/Alice/?page=2"
        #expect(LinkProcessor.organize(url) == "A\n\(url)")
        #expect(LinkProcessor.organize("https://my.erohere.eu/search/") == "S\nhttps://my.erohere.eu/search/")
    }

    @Test func infersUnknownSiteQueryIdentifiers() {
        for query in ["uid=alice", "user_id=alice&page=2", "username=alice", "q=alice", "creator=alice", "page=2&creator=alice"] {
            let url = "https://example.com/search?\(query)"
            #expect(LinkProcessor.organize(url) == "A\n\(url)")
        }
        let url = "https://example.com/?page=2&uid=alice&id=zebra"
        #expect(LinkProcessor.organize(url) == "A\n\(url)")
    }

    @Test func avoidsIncidentalAndAmbiguousParameters() {
        for query in ["page=2", "uid=&page=2", "creator=alice&category=zebra", "utm_source=alice&page=2"] {
            let result = LinkProcessor.organize("https://example.com/search?\(query)")
            #expect(result.hasPrefix("S\n"))
        }
        #expect(LinkProcessor.organize("https://x.com/bob?ref=alice").hasPrefix("B\n"))
    }

    @Test func decodesQueryValuesOnceAndPreservesURL() {
        let url = "https://example.com/profile?username=%61lice%26bob%3D1&page=2"
        #expect(LinkProcessor.organize(url) == "A\nhttps://example.com/profile?username=alice%26bob%3D1&page=2")
        #expect(LinkProcessor.linkCount(in: "\(url)&utm_source=share\n\(url)") == 1)
    }

    @Test func cleansTrackingParametersAndSortsByUsername() async throws {
        let input = """
        https://x.com/ashkillash?s=21
        https://x.com/aliduomu
        https://x.com/alchehehe
        https://x.com/amukeer?s=21
        """

        #expect(LinkProcessor.organize(input) == """
        A
        https://x.com/alchehehe
        https://x.com/aliduomu
        https://x.com/amukeer
        https://x.com/ashkillash
        """)
    }

    @Test func removesCommonTrackingValuesAndDuplicates() async throws {
        let input = "https://instagram.com/Example?utm_source=share&fbclid=123\nhttps://instagram.com/Example"
        #expect(LinkProcessor.organize(input) == "E\nhttps://instagram.com/Example")
    }

    @Test func sortsSupportedProfileTemplatesByTheirActualIdentifiers() async throws {
        let input = """
        https://nhentai.net/artist/zebra/
        https://pixiv.net/users/200
        https://weibo.com/n/alpha
        https://space.bilibili.com/100
        https://youtube.com/@beta
        https://weibo.com/u/300
        https://nhentai.net/artist/able/
        """

        #expect(LinkProcessor.organize(input) == """
        A
        https://nhentai.net/artist/able/
        https://weibo.com/n/alpha
        B
        https://youtube.com/@beta
        Z
        https://nhentai.net/artist/zebra/
        #
        https://space.bilibili.com/100
        https://pixiv.net/users/200
        https://weibo.com/u/300
        """)
    }

    @Test func keepsANotesTitleAndDoesNotCountItAsALink() async throws {
        let input = "My social list\nhttps://x.com/zebra?s=21\nhttps://x.com/able"

        #expect(LinkProcessor.organize(input) == "My social list\nA\nhttps://x.com/able\nZ\nhttps://x.com/zebra")
        #expect(LinkProcessor.linkCount(in: input) == 2)
    }

    @Test func groupsNumbersUnderscoresAndChineseNamesCorrectly() async throws {
        let input = """
        https://x.com/a_b
        https://x.com/aa
        https://x.com/9lives
        https://weibo.com/n/中文
        """

        #expect(LinkProcessor.organize(input) == """
        A
        https://x.com/aa
        https://x.com/a_b
        Z
        https://weibo.com/n/中文
        #
        https://x.com/9lives
        """)
    }

    @Test func displaysUTF8WithoutChangingURLSeparators() {
        let encoded = "https://example.com/search?query=%E4%B8%AD%E6%96%87%26%3D%23%2F%20%25&name=%E6%B5%8B%E8%AF%95"
        let readable = "https://example.com/search?query=中文%26%3D%23/%20%25&name=测试"
        #expect(LinkProcessor.organize(encoded) == "Z\n\(readable)")
        #expect(LinkProcessor.linkCount(in: "\(encoded)\n\(readable)") == 1)
        #expect(LinkProcessor.organize(readable) == "Z\n\(readable)")
    }

    @Test func preservesEscapedUnicodeWhitespaceAndLiteralPercentEncoding() {
        let url = "https://example.com/中文%C2%A0名字%25E4%25B8%25AD"
        #expect(LinkProcessor.organize(url) == "Z\n\(url)")
    }

}
