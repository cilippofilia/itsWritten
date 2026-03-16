//
//  PubMedSearchTool.swift
//  Written
//
//  Created by Filippo Cilia on 15/03/2026.
//

import Foundation
import FoundationModels

struct PubMedSearchTool: Tool {
    let name = "pubmed_search"
    let description = "Search PubMed for relevant biomedical literature and return concise article metadata and abstracts."

    @Generable
    struct Arguments {
        @Guide(description: "PubMed query string, e.g. 'sleep quality adolescents randomized trial'")
        var query: String

        @Guide(description: "Maximum number of results to return", .range(1...10))
        var maxResults: Int?

        @Guide(description: "Include abstracts when available")
        var includeAbstracts: Bool?

        @Guide(description: "Maximum characters in the returned text", .range(1000...12000))
        var maxCharacters: Int?
    }

    func call(arguments: Arguments) async throws -> String {
        let trimmedQuery = arguments.query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedQuery.isEmpty == false else {
            return "No query provided."
        }

        let maxResults = min(max(arguments.maxResults ?? 5, 1), 10)
        let includeAbstracts = arguments.includeAbstracts ?? true
        let maxCharacters = max(arguments.maxCharacters ?? 6000, 1000)

        let ids = try await fetchPubMedIds(for: trimmedQuery, maxResults: maxResults)
        guard ids.isEmpty == false else {
            return "No results found for query: \(trimmedQuery)"
        }

        let articles = try await fetchArticles(ids: ids)
        return format(articles: articles, includeAbstracts: includeAbstracts, maxCharacters: maxCharacters)
    }

    private func fetchPubMedIds(for query: String, maxResults: Int) async throws -> [String] {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "eutils.ncbi.nlm.nih.gov"
        components.path = "/entrez/eutils/esearch.fcgi"
        components.queryItems = [
            URLQueryItem(name: "db", value: "pubmed"),
            URLQueryItem(name: "term", value: query),
            URLQueryItem(name: "retmax", value: String(maxResults)),
            URLQueryItem(name: "retmode", value: "json"),
            URLQueryItem(name: "sort", value: "relevance")
        ]

        guard let url = components.url else {
            return []
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 15

        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response)

        let decoded = try JSONDecoder().decode(ESearchResponse.self, from: data)
        return decoded.esearchresult.idlist
    }

    private func fetchArticles(ids: [String]) async throws -> [PubMedArticle] {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "eutils.ncbi.nlm.nih.gov"
        components.path = "/entrez/eutils/efetch.fcgi"
        components.queryItems = [
            URLQueryItem(name: "db", value: "pubmed"),
            URLQueryItem(name: "id", value: ids.joined(separator: ",")),
            URLQueryItem(name: "retmode", value: "xml")
        ]

        guard let url = components.url else {
            return []
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 20

        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response)

        let parser = PubMedXMLParser()
        return parser.parse(data: data)
    }

    private func format(articles: [PubMedArticle], includeAbstracts: Bool, maxCharacters: Int) -> String {
        var outputLines: [String] = []

        for (index, article) in articles.enumerated() {
            outputLines.append("Result \(index + 1)")
            if article.pmid.isEmpty == false {
                outputLines.append("PMID: \(article.pmid)")
                outputLines.append("URL: https://pubmed.ncbi.nlm.nih.gov/\(article.pmid)/")
            }
            if article.title.isEmpty == false {
                outputLines.append("Title: \(article.title)")
            }
            if article.journal.isEmpty == false {
                outputLines.append("Journal: \(article.journal)")
            }
            if article.year.isEmpty == false {
                outputLines.append("Year: \(article.year)")
            }
            if includeAbstracts, article.abstractText.isEmpty == false {
                outputLines.append("Abstract: \(article.abstractText)")
            }
            outputLines.append("")
        }

        var output = outputLines.joined(separator: "\n")
        if output.count > maxCharacters {
            output = String(output.prefix(maxCharacters)) + "\n[Truncated]"
        }

        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func validate(_ response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw PubMedSearchError.invalidResponse
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            throw PubMedSearchError.httpError(statusCode: httpResponse.statusCode)
        }
    }
}

private struct ESearchResponse: Decodable {
    let esearchresult: ESearchResult

    struct ESearchResult: Decodable {
        let idlist: [String]
    }
}

private struct PubMedArticle: Hashable {
    var pmid: String = ""
    var title: String = ""
    var journal: String = ""
    var year: String = ""
    var abstractSections: [String] = []

    var abstractText: String {
        abstractSections.joined(separator: " ")
    }
}

private final class PubMedXMLParser: NSObject, XMLParserDelegate {
    private var articles: [PubMedArticle] = []
    private var currentArticle: PubMedArticle?
    private var elementStack: [String] = []
    private var currentText = ""
    private var currentAbstractLabel: String?

    func parse(data: Data) -> [PubMedArticle] {
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.parse()
        return articles
    }

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String : String]
    ) {
        elementStack.append(elementName)
        currentText = ""

        if elementName == "PubmedArticle" {
            currentArticle = PubMedArticle()
        }

        if elementName == "AbstractText" {
            currentAbstractLabel = attributeDict["Label"]
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        currentText += string
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        let path = elementStack.joined(separator: "/")
        let trimmed = currentText.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmed.isEmpty == false {
            switch path {
            case "PubmedArticleSet/PubmedArticle/MedlineCitation/PMID":
                currentArticle?.pmid = trimmed
            case "PubmedArticleSet/PubmedArticle/MedlineCitation/Article/ArticleTitle":
                currentArticle?.title = trimmed
            case "PubmedArticleSet/PubmedArticle/MedlineCitation/Article/Journal/Title":
                currentArticle?.journal = trimmed
            case "PubmedArticleSet/PubmedArticle/MedlineCitation/Article/Journal/JournalIssue/PubDate/Year":
                currentArticle?.year = trimmed
            case "PubmedArticleSet/PubmedArticle/MedlineCitation/Article/Journal/JournalIssue/PubDate/MedlineDate":
                if currentArticle?.year.isEmpty ?? true {
                    currentArticle?.year = String(trimmed.prefix(4))
                }
            case "PubmedArticleSet/PubmedArticle/MedlineCitation/Article/Abstract/AbstractText":
                let abstractText: String
                if let label = currentAbstractLabel, label.isEmpty == false {
                    abstractText = "\(label): \(trimmed)"
                } else {
                    abstractText = trimmed
                }
                currentArticle?.abstractSections.append(abstractText)
            default:
                break
            }
        }

        if elementName == "PubmedArticle", let article = currentArticle {
            articles.append(article)
            currentArticle = nil
        }

        if elementStack.isEmpty == false {
            elementStack.removeLast()
        }
        currentText = ""
        currentAbstractLabel = nil
    }
}

private enum PubMedSearchError: LocalizedError {
    case invalidResponse
    case httpError(statusCode: Int)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            "Invalid response from PubMed."
        case .httpError(let statusCode):
            "PubMed request failed with status code \(statusCode)."
        }
    }
}
