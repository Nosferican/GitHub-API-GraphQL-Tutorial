using HTTP, JSON3, DataFrames
const github_user = ""
const github_token = ""
const github_endpoint = "https://api.github.com/graphql"
const github_header = ("User-Agent" => github_user,
                       "Authorization" => string("bearer ", github_token))

parse_edge(edge) = (owner = edge.node.owner.login, name = edge.node.name)

function search(license)
    body = """{
               rateLimit {
                 cost
                 remaining
                 resetAt
                 }
               search(query: \\"license:$license\\",
                      first: 100,
                      type: REPOSITORY) {
                        edges {
                          node {
                            ... on Repository {
                              name
                              owner {
                                login
                                }
                              }
                            }
                          }
                          pageInfo {
                            hasNextPage
                            endCursor
                            }
                          }
                        }""" |>
        (x -> replace(x, "\n" => " ")) |>
        (x -> replace(x, r"\s+" => " ")) |>
        (query -> """{\"query\": \"query $query\" }""")
    request = HTTP.post(github_endpoint,
                        github_header,
                        body)
    @assert request.status == 200 "Status Code is not OK. It is $(request.status)"
    content = String(request.body)
    data = JSON3.read(content)
    @assert haskey(data, :data) "Query had an error"
    output = DataFrame(parse_edge(edge) for edge ∈ data.data.search.edges)
    nextpage = data.data.search.pageInfo.hasNextPage
    while nextpage
        cursor = data.data.search.pageInfo.endCursor
        body = """{
                   rateLimit {
                     cost
                     remaining
                     resetAt
                     }
                   search(query: \\"license:$license\\",
                          first: 100,
                          type: REPOSITORY,
                          after: \\"$cursor\\") {
                            edges {
                              node {
                                ... on Repository {
                                  name
                                  owner {
                                    login
                                    }
                                  }
                                }
                              }
                              pageInfo {
                                hasNextPage
                                endCursor
                                }
                              }
                            }""" |>
            (x -> replace(x, "\n" => " ")) |>
            (x -> replace(x, r"\s+" => " ")) |>
            (query -> """{\"query\": \"query $query\" }""")
        request = HTTP.post(github_endpoint,
                            github_header,
                            body)
        @assert request.status == 200 "Status Code is not OK. It is $(request.status)"
        content = String(request.body)
        data = JSON3.read(content)
        @assert haskey(data, :data) "Query had an error"
        append!(output, DataFrame(parse_edge(edge) for edge ∈ data.data.search.edges))
        nextpage = data.data.search.pageInfo.hasNextPage
    end
    output
end

mit = search("mit")
