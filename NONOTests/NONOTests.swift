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
        https://weibo.com/n/%E4%B8%AD%E6%96%87
        #
        https://x.com/9lives
        """)
    }

}
