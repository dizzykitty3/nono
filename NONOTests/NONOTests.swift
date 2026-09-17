//
//  NONOTests.swift
//  NONOTests
//
//  Created by Theo on 9/17/26.
//

import Testing
@testable import NONO

struct NONOTests {

    @Test func cleansTrackingParametersAndSortsByUsername() async throws {
        let input = """
        https://x.com/ashkillash?s=21
        https://x.com/aliduomu
        https://x.com/alchehehe
        https://x.com/amukeer?s=21
        """

        #expect(LinkProcessor.organize(input) == """
        https://x.com/alchehehe
        https://x.com/aliduomu
        https://x.com/amukeer
        https://x.com/ashkillash
        """)
    }

    @Test func removesCommonTrackingValuesAndDuplicates() async throws {
        let input = "https://instagram.com/Example?utm_source=share&fbclid=123\nhttps://instagram.com/Example"
        #expect(LinkProcessor.organize(input) == "https://instagram.com/Example")
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
        https://nhentai.net/artist/able/
        https://weibo.com/n/alpha
        https://youtube.com/@beta
        https://space.bilibili.com/100
        https://pixiv.net/users/200
        https://weibo.com/u/300
        https://nhentai.net/artist/zebra/
        """)
    }

    @Test func keepsANotesTitleAndDoesNotCountItAsALink() async throws {
        let input = "My social list\nhttps://x.com/zebra?s=21\nhttps://x.com/able"

        #expect(LinkProcessor.organize(input) == "My social list\nhttps://x.com/able\nhttps://x.com/zebra")
        #expect(LinkProcessor.linkCount(in: input) == 2)
    }

}
